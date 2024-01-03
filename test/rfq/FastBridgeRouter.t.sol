// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter, IFastBridge, SwapQuery} from "../../contracts/rfq/FastBridgeRouter.sol";
import {Action, DefaultParams} from "../../contracts/router/libs/Structs.sol";

import {MockFastBridge} from "../mocks/MockFastBridge.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {Test} from "forge-std/Test.sol";

contract FastBridgeRouterTest is Test {
    uint256 constant RFQ_DEADLINE = 12 hours;
    address constant TOKEN_OUT = address(1337);
    uint256 constant FIXED_FEE = 0.01 ether;
    uint32 constant DST_CHAIN_ID = 420;

    FastBridgeRouter public router;
    MockFastBridge public fastBridge;
    address owner;

    MockERC20 public token0;
    MockERC20 public token1;

    MockDefaultPool public pool;

    address user;
    address recipient;

    function setUp() public {
        owner = makeAddr("Owner");
        recipient = makeAddr("Recipient");
        user = makeAddr("User");
        fastBridge = new MockFastBridge();
        router = new FastBridgeRouter(address(fastBridge), owner);

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

    function test_constructor() public {
        assertEq(address(router.fastBridge()), address(fastBridge));
        assertEq(router.owner(), owner);
    }

    function test_bridge_noOriginSwap_noGasRebate() public {
        uint256 amount = 1 ether;
        uint256 amountOut = amount - FIXED_FEE;
        // No swap on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: address(token0),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amountOut,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = IFastBridge.BridgeParams({
            dstChainId: DST_CHAIN_ID,
            sender: user,
            to: recipient,
            originToken: address(token0),
            destToken: TOKEN_OUT,
            originAmount: amount,
            destAmount: amountOut,
            sendChainGas: false,
            deadline: block.timestamp + RFQ_DEADLINE
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_bridge_noOriginSwap_withGasRebate() public {
        uint256 amount = 1 ether;
        uint256 amountOut = amount - FIXED_FEE;
        // No swap on origin chain
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: address(token0),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amountOut,
            deadline: block.timestamp + RFQ_DEADLINE,
            // TODO: encode "With gas rebate on destination chain"
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = IFastBridge.BridgeParams({
            dstChainId: DST_CHAIN_ID,
            sender: user,
            to: recipient,
            originToken: address(token0),
            destToken: TOKEN_OUT,
            originAmount: amount,
            destAmount: amountOut,
            sendChainGas: true,
            deadline: block.timestamp + RFQ_DEADLINE
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function getOriginSwapParams() public view returns (bytes memory) {
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: address(pool),
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        return abi.encode(params);
    }

    function test_bridge_withOriginSwap_noGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        // T0 -> T1 swap on origin chain
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        uint256 amountOut = amount - FIXED_FEE;
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token1),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams()
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amountOut,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = IFastBridge.BridgeParams({
            dstChainId: DST_CHAIN_ID,
            sender: user,
            to: recipient,
            originToken: address(token1),
            destToken: TOKEN_OUT,
            originAmount: amount,
            destAmount: amountOut,
            sendChainGas: false,
            deadline: block.timestamp + RFQ_DEADLINE
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_bridge_withOriginSwap_withGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        // T0 -> T1 swap on origin chain
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        uint256 amountOut = amount - FIXED_FEE;
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token1),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams()
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amountOut,
            deadline: block.timestamp + RFQ_DEADLINE,
            // TODO: encode "With gas rebate on destination chain"
            rawParams: ""
        });
        IFastBridge.BridgeParams memory expectedParams = IFastBridge.BridgeParams({
            dstChainId: DST_CHAIN_ID,
            sender: user,
            to: recipient,
            originToken: address(token1),
            destToken: TOKEN_OUT,
            originAmount: amount,
            destAmount: amountOut,
            sendChainGas: true,
            deadline: block.timestamp + RFQ_DEADLINE
        });
        vm.expectCall(address(fastBridge), abi.encodeCall(IFastBridge.bridge, (expectedParams)));
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: destQuery
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
        checkQueryNoSwap(originQueries[0]);
        // Second query: token0 -> token1
        checkQueryWithSwap(originQueries[1]);
    }

    function checkQueryNoSwap(SwapQuery memory query) internal {
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(token0));
        assertEq(query.minAmountOut, 1 ether);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, "");
    }

    function checkQueryWithSwap(SwapQuery memory query) internal {
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, address(token1));
        assertEq(query.minAmountOut, pool.calculateSwap(0, 1, 1 ether));
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getOriginSwapParams());
    }
}
