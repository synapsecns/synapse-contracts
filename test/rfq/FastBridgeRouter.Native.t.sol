// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFastBridge, SwapQuery} from "../../contracts/rfq/FastBridgeRouter.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../router/mocks/MockWETH.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {FBRTest} from "./FBRTest.sol";

contract FastBridgeRouterNativeTest is FBRTest {
    address public constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    MockERC20 public token;
    MockWETH public weth;

    function setUp() public override {
        super.setUp();
        token = new MockERC20("TKN", 18);
        weth = new MockWETH();

        address[] memory tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(weth);
        pool = new MockDefaultPool(tokens);
        // Mint some tokens to the pool
        token.mint(address(pool), 100 ether);
        weth.mint(address(pool), 120 ether);
        // Mint some tokens to the user
        token.mint(user, 10 ether);
        weth.mint(user, 10 ether);
        deal(user, 10 ether);
        // Approve the Router to spend the user's tokens
        vm.prank(user);
        token.approve(address(router), 10 ether);
        vm.prank(user);
        weth.approve(address(router), 10 ether);
    }

    // ═══════════════════════════════════════════ TESTS: START FROM ETH ═══════════════════════════════════════════════

    // Start from ETH, use ETH for RFQ
    function test_bridge_eth_noOriginSwap_noGasRebate() public {
        uint256 amount = 1 ether;
        // No swap on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: ETH,
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from ETH, use ETH for RFQ (with gas rebate)
    function test_bridge_eth_noOriginSwap_withGasRebate() public {
        uint256 amount = 1 ether;
        // No swap on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: ETH,
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // Start from ETH, use WETH for RFQ
    function test_bridge_eth_withOriginWrap_noGasRebate() public {
        uint256 amount = 1 ether;
        // Wrap ETH on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(weth),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginHandleETHParams()
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from ETH, use WETH for RFQ (with gas rebate)
    function test_bridge_eth_withOriginWrap_withGasRebate() public {
        uint256 amount = 1 ether;
        // Wrap ETH on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(weth),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginHandleETHParams()
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // Start from ETH, use paired token for RFQ
    function test_bridge_eth_withOriginSwap_noGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        // Swap ETH on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams(1, 0)
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge{value: amountBeforeSwap}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from ETH, use paired token for RFQ (with gas rebate)
    function test_bridge_eth_withOriginSwap_withGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        // Swap ETH on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams(1, 0)
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge{value: amountBeforeSwap}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }
}
