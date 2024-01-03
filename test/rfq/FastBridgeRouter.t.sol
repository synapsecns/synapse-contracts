// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFastBridge, SwapQuery} from "../../contracts/rfq/FastBridgeRouter.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {FBRTest} from "./FBRTest.sol";

contract FastBridgeRouterTest is FBRTest {
    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public override {
        super.setUp();
        token0 = new MockERC20("T0", 18);
        token1 = new MockERC20("T1", 18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        pool = new MockDefaultPool(tokens);
        // Mint some tokens to the pool
        token0.mint(address(pool), 100 ether);
        token1.mint(address(pool), 120 ether);
        // Mint some tokens to the user
        token0.mint(user, 10 ether);
        token1.mint(user, 10 ether);
        // Approve the Router to spend the user's tokens
        token0.approve(address(router), 10 ether);
        token1.approve(address(router), 10 ether);
    }

    function test_bridge_noOriginSwap_noGasRebate() public {
        uint256 amount = 1 ether;
        // No swap on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: address(token0),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token0),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_noOriginSwap_withGasRebate() public {
        uint256 amount = 1 ether;
        // No swap on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: address(token0),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token0),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    function test_bridge_withOriginSwap_noGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        // T0 -> T1 swap on origin chain
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token1),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams(0, 1)
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token1),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_withOriginSwap_withGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        // T0 -> T1 swap on origin chain
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token1),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams(0, 1)
        });
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token1),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    function test_getOriginAmountOut() public {
        address[] memory bridgeTokens = new address[](2);
        bridgeTokens[0] = address(token0);
        bridgeTokens[1] = address(token1);
        // Ask for token0 -> [token0, token1] quotes
        SwapQuery[] memory originQueries = router.getOriginAmountOut(address(token0), bridgeTokens, 1 ether);
        // End test prematurely if the returned array is not of length 2
        require(originQueries.length == 2, "Invalid array length");
        // First query: token0 -> token0
        checkQueryNoAction({query: originQueries[0], token: address(token0), amount: 1 ether});
        // Second query: token0 -> token1
        checkQueryWithAction({
            query: originQueries[1],
            token: address(token1),
            amount: pool.calculateSwap(0, 1, 1 ether),
            rawParams: getOriginSwapParams(0, 1)
        });
    }
}
