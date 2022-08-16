// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../../../contracts/bridge/wrappers/OptimismSwapWrapper.sol";
import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";

interface SynthUSD {
    function target() external view returns (SynthUSD);

    function tokenState() external view returns (TokenState);
}

interface TokenState {
    function associatedContract() external view returns (address);

    function setBalanceOf(address, uint256) external;
}

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract SwapWrapperTestOpt is Test {
    using SafeERC20 for IERC20;

    address internal constant NUSD = 0x67C10C397dD0Ba417329543c1a40eb48AAa7cd00;
    address internal constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address internal constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address internal constant SUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address internal constant USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;

    uint8 internal constant COINS = 5;

    OptimismSwapWrapper internal swap;

    function setUp() public {
        swap = new OptimismSwapWrapper();
        for (uint8 i = 0; i < COINS; ++i) {
            swap.getToken(i).safeApprove(address(swap), type(uint256).max);
        }
        vm.label(NUSD, "nUSD");
        vm.label(USDC, "USDC");
        vm.label(DAI, "DAI");
        vm.label(SUSD, "sUSD");
        vm.label(USDT, "USDT");

        vm.label(0xF44938b0125A6662f9536281aD2CD6c499F22004, "nUSD Pool");
        vm.label(0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353, "DAI Pool");
        vm.label(0xd16232ad60188B68076a235c65d692090caba155, "sUSD Pool");
        vm.label(0x1337BedC9D22ecbe766dF105c9623922A27963EC, "USDT Pool");
    }

    function test_tokenNames() public {
        // Sanity checks
        assertEq(ERC20(NUSD).symbol(), "nUSD", "!nUSD token");
        assertEq(ERC20(USDC).symbol(), "USDC", "!USC token");
        assertEq(ERC20(DAI).symbol(), "DAI", "!DAI token");
        assertEq(ERC20(SUSD).symbol(), "sUSD", "!sUSD token");
        assertEq(ERC20(USDT).symbol(), "USDT", "!USDT token");
    }

    function test_getToken() public {
        assertEq(address(swap.getToken(0)), NUSD, "!nUSD index");
        assertEq(address(swap.getToken(1)), USDC, "!USDC index");
        assertEq(address(swap.getToken(2)), DAI, "!DAI index");
        assertEq(address(swap.getToken(3)), SUSD, "!sUSD index");
        assertEq(address(swap.getToken(4)), USDT, "!USDT index");
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
        vm.expectRevert("Deadline not met");
        swap.swap(0, 1, 0, 0, block.timestamp - 1);
    }

    function test_swap_amountOutTooLow() public {
        for (uint8 indexFrom = 0; indexFrom < COINS; ++indexFrom) {
            for (uint8 indexTo = 0; indexTo < COINS; ++indexTo) {
                if (indexFrom != indexTo) {
                    (, uint256 amountIn) = _prepareSwap(indexFrom, indexTo);
                    uint256 quoteOut = swap.calculateSwap(indexFrom, indexTo, amountIn);
                    assert(quoteOut != 0);
                    vm.expectRevert("Swap didn't result in min tokens");
                    swap.swap(indexFrom, indexTo, amountIn, 2 * quoteOut, block.timestamp);
                }
            }
        }
    }

    function _checkSwap(uint8 _indexFrom, uint8 _indexTo) internal {
        (, uint256 amountIn) = _prepareSwap(_indexFrom, _indexTo);
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

    function _prepareSwap(uint8 _indexFrom, uint8 _indexTo) internal returns (IERC20 tokenIn, uint256 amountIn) {
        assert(_indexFrom != _indexTo);
        tokenIn = _getToken(_indexFrom);
        amountIn = _getTestAmountIn(address(tokenIn));
        // Mint test tokens
        if (address(tokenIn) == SUSD) {
            // Minting test sUSD is pure pain
            TokenState state = SynthUSD(address(tokenIn)).target().tokenState();
            vm.prank(state.associatedContract());
            state.setBalanceOf(address(this), amountIn);
        } else {
            deal(address(tokenIn), address(this), amountIn);
        }
    }

    function _getToken(uint8 _index) internal view returns (IERC20) {
        return swap.getToken(_index);
    }

    function _getTestAmountIn(address _token) internal view returns (uint256) {
        // $1000 in token's decimals
        return 1000 * 10**ERC20(_token).decimals();
    }
}
