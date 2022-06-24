// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import {IL2BridgeZap} from "../interfaces/IL2BridgeZap.sol";
import {ISwap} from "../interfaces/ISwap.sol";
import {BridgeEvents} from "../interfaces/BridgeEvents.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";
import {IWETH9} from "../../../contracts/bridge/interfaces/IWETH9.sol";

// solhint-disable not-rely-on-time
// solhint-disable func-name-mixedcase

abstract contract DefaultL2BridgeZapTest is Test, BridgeEvents {
    struct L2ZapTestSetup {
        address wethAddress;
        address synapseBridge;
        address tokenDeposit;
        address tokenRedeem;
    }

    address payable internal wethAddress;
    address internal synapseBridge;

    IERC20 internal tokenDeposit;
    IERC20 internal tokenRedeem;

    address internal dummyToken;

    address[] internal swaps;
    address[] internal bridgeTokens;

    IL2BridgeZap internal zap;

    uint256 internal constant CHAIN_ID = 69;
    uint256 internal constant AMOUNT = 10**18;
    address internal constant USER = address(1337420);
    bytes32 internal constant USER_32 = keccak256("user");

    address internal constant ZERO = address(0);
    IERC20 internal constant NULL = IERC20(ZERO);

    constructor(L2ZapTestSetup memory _setup) {
        wethAddress = payable(_setup.wethAddress);
        synapseBridge = _setup.synapseBridge;

        tokenDeposit = IERC20(_setup.tokenDeposit);
        tokenRedeem = IERC20(_setup.tokenRedeem);

        _initSwapArrays();
    }

    function setUp() public virtual {
        zap = IL2BridgeZap(deployCode("L2BridgeZap.sol", abi.encode(wethAddress, swaps, bridgeTokens, synapseBridge)));

        dummyToken = deployCode("ERC20Mock.sol", abi.encode("TEST", "TEST", 0));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                  TEST FUNCTIONS: RESTRICTED ACCESS                   ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_setInfiniteAllowance() public {
        IERC20 token = IERC20(dummyToken);
        zap.setInfiniteAllowance(token, USER);
        assertEq(token.allowance(address(zap), USER), type(uint256).max, "Allowance not set");
    }

    function test_setInfiniteAllowance_asNotOwner() public {
        vm.prank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        zap.setInfiniteAllowance(IERC20(dummyToken), USER);
    }

    function test_setTokenPool() public {
        if (_checkIfSwapTestSkipped()) return;
        ISwap swap = ISwap(swaps[0]);
        IERC20 token = IERC20(dummyToken);
        zap.setTokenPool(swap, token);
        assertEq(address(zap.swapMap(token)), address(swap), "Swap pool not set");
    }

    function test_setTokenPool_asNotOwner() public {
        vm.prank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        zap.setTokenPool(ISwap(address(0)), IERC20(dummyToken));
    }

    function test_removeTokenPool() public {
        if (_checkIfSwapTestSkipped()) return;
        IERC20 bridgeToken = IERC20(bridgeTokens[0]);
        zap.removeTokenPool(bridgeToken);
        assertEq(address(zap.swapMap(bridgeToken)), address(0), "Swap pool not removed");
    }

    function test_removeTokenPool_asNotOwner() public {
        vm.prank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        zap.removeTokenPool(IERC20(dummyToken));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TEST FUNCTIONS: SWAP                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_swapAndRedeem() public {
        _test_swap_generic(_runTest_swapAndRedeem);
    }

    function test_swapAndRedeemAndSwap() public {
        _test_swap_generic(_runTest_swapAndRedeemAndSwap);
    }

    function test_swapAndRedeemAndRemove() public {
        _test_swap_generic(_runTest_swapAndRedeemAndRemove);
    }

    function test_swapETHAndRedeem() public {
        _test_swap_ETH_generic(_runTest_swapETHAndRedeem);
    }

    function test_swapETHAndRedeemAndSwap() public {
        _test_swap_ETH_generic(_runTest_swapETHAndRedeemAndSwap);
    }

    function _testAllTokenSwaps() internal {
        test_swapAndRedeem();
        test_swapAndRedeemAndSwap();
        test_swapAndRedeemAndRemove();
    }

    function _testAllETHSwaps() internal {
        test_swapETHAndRedeem();
        test_swapETHAndRedeemAndSwap();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TEST FUNCTIONS: NO SWAP                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_deposit() public {
        _test_noSwap_generic(tokenDeposit, _runTest_deposit);
    }

    function test_redeem() public {
        _test_noSwap_generic(tokenRedeem, _runTest_redeem);
    }

    function test_redeemAndSwap() public {
        _test_noSwap_generic(tokenRedeem, _runTest_redeemAndSwap);
    }

    function test_redeemAndRemove() public {
        _test_noSwap_generic(tokenRedeem, _runTest_redeemAndRemove);
    }

    function test_redeemV2() public {
        _test_noSwap_generic(tokenRedeem, _runTest_redeemV2);
    }

    function test_depositETH() public {
        _test_noSwap_ETH_generic(_runTest_depositETH);
    }

    function test_depositETHAndSwap() public {
        _test_noSwap_ETH_generic(_runTest_depositETHAndSwap);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      SWAP TESTS IMPLEMENTATION                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_swap_generic(function(IERC20, uint8, uint8, uint256, uint256) _runTest) internal {
        if (_checkIfSwapTestSkipped()) return;
        for (uint256 index = 0; index < swaps.length; ++index) {
            // check all bridge tokens that were set up
            (uint8 bridgeTokenIndex, uint8 swapTokens) = _getBridgeTokenIndex(index);
            IERC20 bridgeToken = IERC20(bridgeTokens[index]);
            for (uint8 indexFrom = 0; indexFrom < swapTokens; ++indexFrom) {
                // check all candidates for "initial token"
                if (indexFrom == bridgeTokenIndex) continue;
                IERC20 tokenFrom = _getToken(index, indexFrom);
                // Use 1.0 worth of tokens for swapping
                uint256 amount = 10**ERC20(address(tokenFrom)).decimals();
                // get quote for swap, will be used for event checking
                uint256 quote = _getQuote(index, indexFrom, bridgeTokenIndex, amount);
                // deal test tokens to user and approve Zap to spend them
                _prepareTestTokens(tokenFrom, amount);
                _logSwapTest(index, indexFrom, bridgeTokenIndex);
                vm.expectEmit(true, true, true, true);
                _runTest(bridgeToken, indexFrom, bridgeTokenIndex, amount, quote);
            }
        }
    }

    function _runTest_swapAndRedeem(
        IERC20 _bridgeToken,
        uint8 _indexFrom,
        uint8 _bridgeTokenIndex,
        uint256 _amount,
        uint256 _quote
    ) internal {
        emit TokenRedeem(USER, CHAIN_ID, _bridgeToken, _quote);
        vm.prank(USER);
        zap.swapAndRedeem(
            USER,
            CHAIN_ID,
            _bridgeToken,
            _indexFrom,
            _bridgeTokenIndex,
            _amount,
            _quote,
            block.timestamp
        );
    }

    function _runTest_swapAndRedeemAndSwap(
        IERC20 _bridgeToken,
        uint8 _indexFrom,
        uint8 _bridgeTokenIndex,
        uint256 _amount,
        uint256 _quote
    ) internal {
        // Use different non-zero placeholder values for testing remote chain arguments
        emit TokenRedeemAndSwap(USER, CHAIN_ID, _bridgeToken, _quote, 1, 2, 3, 4);
        vm.prank(USER);
        zap.swapAndRedeemAndSwap(
            USER,
            CHAIN_ID,
            _bridgeToken,
            _indexFrom,
            _bridgeTokenIndex,
            _amount,
            _quote,
            block.timestamp,
            1,
            2,
            3,
            4
        );
    }

    function _runTest_swapAndRedeemAndRemove(
        IERC20 _bridgeToken,
        uint8 _indexFrom,
        uint8 _bridgeTokenIndex,
        uint256 _amount,
        uint256 _quote
    ) internal {
        // Use different non-zero placeholder values for testing remote chain arguments
        emit TokenRedeemAndRemove(USER, CHAIN_ID, _bridgeToken, _quote, 1, 2, 3);
        vm.prank(USER);
        zap.swapAndRedeemAndRemove(
            USER,
            CHAIN_ID,
            _bridgeToken,
            _indexFrom,
            _bridgeTokenIndex,
            _amount,
            _quote,
            block.timestamp,
            1,
            2,
            3
        );
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                   SWAP TESTS IMPLEMENTATION (GAS)                    ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_swap_ETH_generic(function(IERC20, uint8, uint8, uint256) _runTest) internal {
        if (_checkIfSwapTestSkipped()) return;
        (uint256 globalIndex, uint8 ethIndex, uint8 bridgeTokenIndex) = _findEthPool();
        if (ethIndex == bridgeTokenIndex) {
            emit log_string("Skipping: pool with WGAS not found");
            return;
        }

        IERC20 bridgeToken = IERC20(bridgeTokens[globalIndex]);
        uint256 quote = _getQuote(globalIndex, ethIndex, bridgeTokenIndex, AMOUNT);
        deal(USER, AMOUNT);

        _logSwapTest(globalIndex, ethIndex, bridgeTokenIndex);
        vm.expectEmit(true, true, true, true);
        _runTest(bridgeToken, ethIndex, bridgeTokenIndex, quote);
    }

    function _runTest_swapETHAndRedeem(
        IERC20 _bridgeToken,
        uint8 _indexFrom,
        uint8 _bridgeTokenIndex,
        uint256 _quote
    ) internal {
        emit TokenRedeem(USER, CHAIN_ID, _bridgeToken, _quote);
        vm.prank(USER);
        zap.swapETHAndRedeem{value: AMOUNT}(
            USER,
            CHAIN_ID,
            _bridgeToken,
            _indexFrom,
            _bridgeTokenIndex,
            AMOUNT,
            _quote,
            block.timestamp
        );
    }

    function _runTest_swapETHAndRedeemAndSwap(
        IERC20 _bridgeToken,
        uint8 _indexFrom,
        uint8 _bridgeTokenIndex,
        uint256 _quote
    ) internal {
        // Use different non-zero placeholder values for testing remote chain arguments
        emit TokenRedeemAndSwap(USER, CHAIN_ID, _bridgeToken, _quote, 1, 2, 3, 4);
        vm.prank(USER);
        zap.swapETHAndRedeemAndSwap{value: AMOUNT}(
            USER,
            CHAIN_ID,
            _bridgeToken,
            _indexFrom,
            _bridgeTokenIndex,
            AMOUNT,
            _quote,
            block.timestamp,
            1,
            2,
            3,
            4
        );
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     NO-SWAP TESTS IMPLEMENTATION                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_noSwap_generic(IERC20 _token, function(IERC20) _runTest) internal {
        if (_checkIfNoSwapTestSkipped(_token)) return;
        _prepareTestTokens(_token, AMOUNT);
        _logNoSwapTest(_token);
        vm.expectEmit(true, true, true, true);
        _runTest(_token);
    }

    function _runTest_redeem(IERC20 _token) internal {
        emit TokenRedeem(USER, CHAIN_ID, _token, AMOUNT);
        vm.prank(USER);
        zap.redeem(USER, CHAIN_ID, _token, AMOUNT);
    }

    function _runTest_deposit(IERC20 _token) internal {
        emit TokenDeposit(USER, CHAIN_ID, _token, AMOUNT);
        vm.prank(USER);
        zap.deposit(USER, CHAIN_ID, _token, AMOUNT);
    }

    function _runTest_redeemAndSwap(IERC20 _token) internal {
        // Use different non-zero placeholder values for testing remote chain arguments
        emit TokenRedeemAndSwap(USER, CHAIN_ID, _token, AMOUNT, 1, 2, 3, 4);
        vm.prank(USER);
        zap.redeemAndSwap(USER, CHAIN_ID, _token, AMOUNT, 1, 2, 3, 4);
    }

    function _runTest_redeemAndRemove(IERC20 _token) internal {
        // Use different non-zero placeholder values for testing remote chain arguments
        emit TokenRedeemAndRemove(USER, CHAIN_ID, _token, AMOUNT, 1, 2, 3);
        vm.prank(USER);
        zap.redeemAndRemove(USER, CHAIN_ID, _token, AMOUNT, 1, 2, 3);
    }

    function _runTest_redeemV2(IERC20 _token) internal {
        emit TokenRedeemV2(USER_32, CHAIN_ID, _token, AMOUNT);
        vm.prank(USER);
        zap.redeemV2(USER_32, CHAIN_ID, _token, AMOUNT);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                  NO-SWAP TESTS IMPLEMENTATION (GAS)                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_noSwap_ETH_generic(function() _runTest) internal {
        if (wethAddress == ZERO) {
            emit log_string("Skipping: WETH_ADDRESS not configured");
            return;
        }
        deal(USER, AMOUNT);
        _logNoSwapTest(IERC20(wethAddress));
        vm.expectEmit(true, true, true, true);
        _runTest();
    }

    function _runTest_depositETH() internal {
        emit TokenDeposit(USER, CHAIN_ID, IERC20(wethAddress), AMOUNT);
        vm.prank(USER);
        zap.depositETH{value: AMOUNT}(USER, CHAIN_ID, AMOUNT);
    }

    function _runTest_depositETHAndSwap() internal {
        // Use different non-zero placeholder values for testing remote chain arguments
        emit TokenDepositAndSwap(USER, CHAIN_ID, IERC20(wethAddress), AMOUNT, 1, 2, 3, 4);
        vm.prank(USER);
        zap.depositETHAndSwap{value: AMOUNT}(USER, CHAIN_ID, AMOUNT, 1, 2, 3, 4);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _addBridgePool(address _bridgeToken, address _swap) internal {
        bridgeTokens.push(_bridgeToken);
        swaps.push(_swap);
    }

    function _checkIfSwapTestSkipped() internal returns (bool skipped) {
        if (swaps.length == 0) {
            emit log_string("Skipping: no swap pools configured");
            skipped = true;
        }
    }

    function _checkIfNoSwapTestSkipped(IERC20 _token) internal returns (bool skipped) {
        if (address(_token) == ZERO) {
            emit log_string("Skipping: no bridge token configured");
            skipped = true;
        }
    }

    function _clearSavedPools() internal {
        delete swaps;
        delete bridgeTokens;
    }

    function _findEthPool()
        internal
        view
        returns (
            uint256 globalIndex,
            uint8 ethIndex,
            uint8 bridgeTokenIndex
        )
    {
        for (; globalIndex < swaps.length; ++globalIndex) {
            (uint8 bridgeIndex, uint8 swapTokens) = _getBridgeTokenIndex(globalIndex);
            for (uint8 index = 0; index < swapTokens; ++index) {
                if (index == bridgeIndex) continue;
                if (address(_getToken(globalIndex, index)) == wethAddress) {
                    return (globalIndex, index, bridgeIndex);
                }
            }
        }
        return (0, 0, 0);
    }

    function _getBridgeTokenIndex(uint256 _globalIndex) internal view returns (uint8 index, uint8 swapTokens) {
        ISwap swap = ISwap(swaps[_globalIndex]);
        address bridgeToken = bridgeTokens[_globalIndex];
        index = type(uint8).max;
        for (; ; ++swapTokens) {
            try swap.getToken(swapTokens) returns (IERC20 token) {
                if (address(token) == bridgeToken) index = swapTokens;
            } catch {
                break;
            }
        }
        if (index == type(uint8).max) revert("Token not found");
    }

    function _getToken(uint256 _globalIndex, uint8 _poolIndex) internal view returns (IERC20) {
        return ISwap(swaps[_globalIndex]).getToken(_poolIndex);
    }

    function _getQuote(
        uint256 _globalIndex,
        uint8 _indexFrom,
        uint8 _indexTo,
        uint256 _amount
    ) internal view returns (uint256) {
        return ISwap(swaps[_globalIndex]).calculateSwap(_indexFrom, _indexTo, _amount);
    }

    function _logSwapTest(
        uint256 _globalIndex,
        uint8 _indexFrom,
        uint8 _indexTo
    ) internal {
        ERC20 tokenFrom = ERC20(address(_getToken(_globalIndex, _indexFrom)));
        ERC20 tokenTo = ERC20(address(_getToken(_globalIndex, _indexTo)));
        emit log_string(string.concat(tokenFrom.symbol(), " -> ", tokenTo.symbol()));
    }

    function _logNoSwapTest(IERC20 _token) internal {
        ERC20 token = ERC20(address(_token));
        emit log_string(string.concat("Bridging ", token.symbol()));
    }

    function _prepareTestTokens(IERC20 _token, uint256 _amount) internal {
        if (address(_token) == wethAddress) {
            deal(USER, _amount);
            vm.prank(USER);
            IWETH9(wethAddress).deposit{value: _amount}();
        } else {
            deal(address(_token), USER, _amount, true);
        }
        vm.prank(USER);
        _token.approve(address(zap), _amount);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          VIRTUAL FUNCTIONS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _initSwapArrays() internal virtual;
}
