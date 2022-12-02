// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "../../../../contracts/bridge/wrappers/swap/CantoSwapWrapper.sol";
import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";

interface ISynapseTest is ISynapse {
    function addLiquidity(
        uint256[] memory amounts,
        uint256 minToMint,
        uint256 deadline
    ) external;

    function getTokenIndex(address) external view returns (uint8);
}

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract NewSwapWrapperTestCanto is Test {
    using SafeERC20 for IERC20;

    address internal constant NUSD = 0xD8836aF2e565D3Befce7D906Af63ee45a57E8f80;
    address internal constant NOTE = 0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503;
    address internal constant USDC = 0x80b5a32E4F032B2a058b4F29EC95EEfEEB87aDcd;
    address internal constant USDT = 0xd567B3d7B8FE3C79a1AD8dA978812cfC4Fa05e75;

    uint8 internal constant COINS = 4;

    ISynapseTest internal constant SYNAPSE_POOL = ISynapseTest(0xb1Da21B0531257a7E5aEfa0cd3CbF23AfC674cE1);
    ICantoDex internal constant CANTO_DEX_USDC_POOL = ICantoDex(0x9571997a66D63958e1B3De9647C22bD6b9e7228c);
    ICantoDex internal constant CANTO_DEX_USDT_POOL = ICantoDex(0x35DB1f3a6A6F07f82C76fCC415dB6cFB1a7df833);

    CantoSwapWrapper internal swap;

    function setUp() public {
        vm.label(NUSD, "nUSD");
        vm.label(NOTE, "NOTE");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");

        vm.label(address(SYNAPSE_POOL), "nUSD/USDC");
        vm.label(address(CANTO_DEX_USDC_POOL), "NOTE/USDC");
        vm.label(address(CANTO_DEX_USDT_POOL), "NOTE/USDT");

        swap = new CantoSwapWrapper();
        for (uint8 i = 0; i < COINS; ++i) {
            swap.getToken(i).safeApprove(address(swap), type(uint256).max);
        }

        // Provide initial liquidity in Synapse pool
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _getTestAmountIn(NUSD) * 100;
        amounts[1] = _getTestAmountIn(USDC) * 100;
        deal(NUSD, address(this), amounts[0]);
        deal(USDC, address(this), amounts[1]);
        IERC20(NUSD).safeApprove(address(SYNAPSE_POOL), type(uint256).max);
        IERC20(USDC).safeApprove(address(SYNAPSE_POOL), type(uint256).max);
        SYNAPSE_POOL.addLiquidity(amounts, 0, block.timestamp);
    }

    function test_tokenNames() public {
        // Sanity checks
        assertEq(ERC20(NUSD).symbol(), "nUSD", "!nUSD token");
        assertEq(ERC20(NOTE).symbol(), "NOTE", "!NOTE token");
        assertEq(ERC20(USDC).symbol(), "USDC", "!USDC token");
        assertEq(ERC20(USDT).symbol(), "USDT", "!USDT token");
    }

    function test_getToken() public {
        assertEq(address(swap.getToken(0)), NUSD, "!nUSD index");
        assertEq(address(swap.getToken(1)), NOTE, "!NOTE index");
        assertEq(address(swap.getToken(2)), USDC, "!USDC index");
        assertEq(address(swap.getToken(3)), USDT, "!USDT index");
    }

    function test_getToken_outOfRange() public {
        vm.expectRevert("Out of range");
        swap.getToken(COINS);
    }

    function test_calculateSwap_identicalIndex() public {
        for (uint8 index = 0; index < COINS; ++index) {
            assertEq(swap.calculateSwap(index, index, _getTestAmountIn(address(_getToken(index)))), 0);
        }
    }

    function test_calculateSwap_unsupportedIndex() public {
        uint256 amountIn = _getTestAmountIn(NUSD);
        assertEq(swap.calculateSwap(0, COINS, amountIn), 0, "nUSD -> ????");
        assertEq(swap.calculateSwap(COINS, 0, amountIn), 0, "???? -> nUSD");
    }

    function test_calculateSwap_directSynapse() public {
        _checkDirectSynapseQuote(NUSD, USDC);
        _checkDirectSynapseQuote(USDC, NUSD);
    }

    function test_calculateSwap_directCantoDEX() public {
        _checkDirectCantoDEXQuote(NOTE, USDC, CANTO_DEX_USDC_POOL);
        _checkDirectCantoDEXQuote(USDC, NOTE, CANTO_DEX_USDC_POOL);

        _checkDirectCantoDEXQuote(NOTE, USDT, CANTO_DEX_USDT_POOL);
        _checkDirectCantoDEXQuote(USDT, NOTE, CANTO_DEX_USDT_POOL);
    }

    function test_swap() public {
        for (uint8 indexFrom = 0; indexFrom < COINS; ++indexFrom) {
            for (uint8 indexTo = 0; indexTo < COINS; ++indexTo) {
                if (indexFrom != indexTo) _checkSwap(indexFrom, indexTo);
            }
        }
    }

    function test_swap_identicalIndex() public {
        for (uint8 indexFrom = 0; indexFrom < COINS; ++indexFrom) {
            vm.expectRevert("Swap not supported");
            swap.swap(indexFrom, indexFrom, 0, 0, type(uint256).max);
        }
    }

    function test_swap_unsupportedIndex() public {
        for (uint8 indexFrom = 0; indexFrom < COINS; ++indexFrom) {
            vm.expectRevert("Swap not supported");
            swap.swap(indexFrom, COINS, 0, 0, type(uint256).max);
            vm.expectRevert("Swap not supported");
            swap.swap(COINS, indexFrom, 0, 0, type(uint256).max);
        }
    }

    function test_swap_deadlineFailed() public {
        for (uint8 indexFrom = 0; indexFrom < COINS; ++indexFrom) {
            for (uint8 indexTo = 0; indexTo < COINS; ++indexTo) {
                if (indexFrom != indexTo) {
                    vm.expectRevert("Deadline not met");
                    swap.swap(indexFrom, indexTo, 0, 0, block.timestamp - 1);
                }
            }
        }
    }

    function test_swap_amountOutTooLow() public {
        for (uint8 indexFrom = 0; indexFrom < COINS; ++indexFrom) {
            for (uint8 indexTo = 0; indexTo < COINS; ++indexTo) {
                if (indexFrom != indexTo) {
                    uint256 amountIn = _prepareSwap(indexFrom, indexTo);
                    uint256 quoteOut = swap.calculateSwap(indexFrom, indexTo, amountIn);
                    assert(quoteOut != 0);
                    vm.expectRevert("Swap didn't result in min tokens");
                    swap.swap(indexFrom, indexTo, amountIn, 2 * quoteOut, block.timestamp);
                }
            }
        }
    }

    function _checkSwap(uint8 _indexFrom, uint8 _indexTo) internal {
        uint256 amountIn = _prepareSwap(_indexFrom, _indexTo);
        IERC20 tokenOut = _getToken(_indexTo);
        // Get swap quote
        uint256 quoteOut = swap.calculateSwap(_indexFrom, _indexTo, amountIn);
        uint256 balanceBefore = tokenOut.balanceOf(address(this));
        // Do the swap
        uint256 amountOut = swap.swap(_indexFrom, _indexTo, amountIn, quoteOut, block.timestamp);
        uint256 balanceAfter = tokenOut.balanceOf(address(this));
        assertEq(amountOut, balanceAfter - balanceBefore, "Failed to report swapped amount");
        assertEq(quoteOut, amountOut, "Failed to give accurate quote");
    }

    function _checkDirectSynapseQuote(address _tokenFrom, address _tokenTo) internal {
        uint256 amountIn = _getTestAmountIn(_tokenFrom);
        uint256 quoteOut = swap.calculateSwap(_getIndex(_tokenFrom), _getIndex(_tokenTo), amountIn);
        uint256 synapseQuote = SYNAPSE_POOL.calculateSwap(
            SYNAPSE_POOL.getTokenIndex(_tokenFrom),
            SYNAPSE_POOL.getTokenIndex(_tokenTo),
            amountIn
        );
        assertEq(quoteOut, synapseQuote, "Quote doesn't match Synapse");
    }

    function _checkDirectCantoDEXQuote(
        address _tokenFrom,
        address _tokenTo,
        ICantoDex _pool
    ) internal {
        uint256 amountIn = _getTestAmountIn(_tokenFrom);
        uint256 quoteOut = swap.calculateSwap(_getIndex(_tokenFrom), _getIndex(_tokenTo), amountIn);
        uint256 cantoDEXQuote = _pool.getAmountOut(amountIn, _tokenFrom);
        assertEq(quoteOut, cantoDEXQuote, "Quote doesn't match CantoDEX");
    }

    function _prepareSwap(uint8 _indexFrom, uint8 _indexTo) internal returns (uint256 amountIn) {
        assert(_indexFrom != _indexTo);
        address tokenIn = address(_getToken(_indexFrom));
        amountIn = _getTestAmountIn(tokenIn);
        // Mint test tokens
        deal(tokenIn, address(this), amountIn);
    }

    function _getIndex(address _token) internal view returns (uint8) {
        for (uint8 index = 0; index < COINS; ++index) {
            if (address(_getToken(index)) == _token) return index;
        }
        revert("Token not found");
    }

    function _getToken(uint8 _index) internal view returns (IERC20) {
        return swap.getToken(_index);
    }

    function _getTestAmountIn(address _token) internal view returns (uint256) {
        // $1000 in token's decimals
        return 1000 * 10**ERC20(_token).decimals();
    }
}
