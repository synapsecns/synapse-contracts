// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFastBridge, SwapQuery} from "../../contracts/rfq/FastBridgeRouter.sol";
import {MsgValueIncorrect, TokenNotContract, TokenNotETH} from "../../contracts/router/libs/Errors.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../router/mocks/MockWETH.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {FBRTest} from "./FBRTest.sol";

abstract contract FastBridgeRouterNativeTest is FBRTest {
    address public constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    MockERC20 public token;
    MockWETH public weth;

    function setUp() public virtual override {
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
        prepareAccount(user);
        setUpSwapQuoter();
    }

    function prepareAccount(address account) public {
        token.mint(user, 10 ether);
        weth.mint(user, 10 ether);
        deal(user, 10 ether);
        vm.prank(user);
        token.approve(address(router), 10 ether);
        vm.prank(user);
        weth.approve(address(router), 10 ether);
    }

    function setUpSwapQuoter() internal virtual;

    function getOriginQueryNoSwap(address tokenOut, uint256 amount)
        internal
        view
        returns (SwapQuery memory originQuery)
    {
        originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: tokenOut,
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
    }

    function getOriginQueryWithSwap(address tokenOut, uint256 amount)
        internal
        view
        returns (SwapQuery memory originQuery)
    {
        originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: tokenOut,
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: tokenOut == address(token) ? getOriginSwapParams(1, 0) : getOriginSwapParams(0, 1)
        });
    }

    function getOriginQueryWithHandleETH(address tokenOut, uint256 amount)
        internal
        view
        returns (SwapQuery memory originQuery)
    {
        originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: tokenOut,
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginHandleETHParams()
        });
    }

    // ═══════════════════════════════════════════ TESTS: START FROM ETH ═══════════════════════════════════════════════

    // Start from ETH, use ETH for RFQ
    function test_bridge_eth_noOriginSwap_noGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
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
        SwapQuery memory originQuery = getOriginQueryNoSwap(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
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
        SwapQuery memory originQuery = getOriginQueryWithHandleETH(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
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
        SwapQuery memory originQuery = getOriginQueryWithHandleETH(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
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
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
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
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
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

    // ══════════════════════════════════════════ TESTS: START FROM WETH ═══════════════════════════════════════════════

    // Start from WETH, use WETH for RFQ
    function test_bridge_weth_noOriginSwap_noGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from WETH, use WETH for RFQ (with gas rebate)
    function test_bridge_weth_noOriginSwap_withGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // Start from WETH, use ETH for RFQ
    function test_bridge_weth_withOriginUnwrap_noGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryWithHandleETH(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from WETH, use ETH for RFQ (with gas rebate)
    function test_bridge_weth_withOriginUnwrap_withGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryWithHandleETH(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // Start from WETH, use paired token for RFQ
    function test_bridge_weth_withOriginSwap_noGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from WETH, use paired token for RFQ (with gas rebate)
    function test_bridge_weth_withOriginSwap_withGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // ══════════════════════════════════════ TESTS: START FROM PAIRED TOKEN ═══════════════════════════════════════════

    // Start from paired token, use paired token for RFQ
    function test_bridge_token_noOriginSwap_noGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from paired token, use paired token for RFQ (with gas rebate)
    function test_bridge_token_noOriginSwap_withGasRebate() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // Start from paired token, use WETH for RFQ
    function test_bridge_token_withOriginSwap_noGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from paired token, use WETH for RFQ (with gas rebate)
    function test_bridge_token_withOriginSwap_withGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // Start from paired token, use ETH for RFQ
    function test_bridge_token_withOriginSwapUnwrap_noGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: false
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // Start from paired token, use ETH for RFQ (with gas rebate)
    function test_bridge_token_withOriginSwapUnwrap_withGasRebate() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: true
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // ══════════════════════════════════════════════ TESTS: REVERTS ═══════════════════════════════════════════════════

    function test_bridge_revert_msgValueWithERC20() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(token), amount);
        vm.expectRevert(TokenNotETH.selector);
        vm.prank(user);
        router.bridge{value: 1 ether}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_revert_msgValueZeroWithETH() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(ETH, amount);
        vm.expectRevert(TokenNotContract.selector);
        vm.prank(user);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_revert_msgValueLowerWithETH() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(ETH, amount);
        vm.expectRevert(MsgValueIncorrect.selector);
        vm.prank(user);
        router.bridge{value: amount - 1}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_revert_msgValueHigherWithETH() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(ETH, amount);
        vm.expectRevert(MsgValueIncorrect.selector);
        vm.prank(user);
        router.bridge{value: amount + 1}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    // ═══════════════════════════════════════ TESTS: GET ORIGIN AMOUNT OUT ════════════════════════════════════════════

    function test_getOriginAmountOut_fromETH() public {
        uint256 amount = 1 ether;
        address[] memory tokens = new address[](3);
        tokens[0] = ETH;
        tokens[1] = address(weth);
        tokens[2] = address(token);
        // Ask for ETH -> [ETH, WETH, TKN] quotes
        SwapQuery[] memory originQueries = router.getOriginAmountOut(ETH, tokens, amount);
        // End test prematurely if the returned array is not of length 3
        require(originQueries.length == 3, "Invalid array length");
        // First query: ETH -> ETH
        checkQueryNoAction({query: originQueries[0], token: ETH, amount: amount});
        // Second query: ETH -> WETH
        checkQueryWithAction({
            query: originQueries[1],
            token: address(weth),
            amount: amount,
            rawParams: getOriginHandleETHParams()
        });
        // Third query: ETH -> TKN
        checkQueryWithAction({
            query: originQueries[2],
            token: address(token),
            amount: pool.calculateSwap(1, 0, amount),
            rawParams: getOriginSwapParams(1, 0)
        });
    }

    function test_getOriginAmountOut_fromWETH() public {
        uint256 amount = 1 ether;
        address[] memory tokens = new address[](3);
        tokens[0] = ETH;
        tokens[1] = address(weth);
        tokens[2] = address(token);
        // Ask for WETH -> [ETH, WETH, TKN] quotes
        SwapQuery[] memory originQueries = router.getOriginAmountOut(address(weth), tokens, amount);
        // End test prematurely if the returned array is not of length 3
        require(originQueries.length == 3, "Invalid array length");
        // First query: WETH -> ETH
        checkQueryWithAction({
            query: originQueries[0],
            token: ETH,
            amount: amount,
            rawParams: getOriginHandleETHParams()
        });
        // Second query: WETH -> WETH
        checkQueryNoAction({query: originQueries[1], token: address(weth), amount: amount});
        // Third query: WETH -> TKN
        checkQueryWithAction({
            query: originQueries[2],
            token: address(token),
            amount: pool.calculateSwap(1, 0, amount),
            rawParams: getOriginSwapParams(1, 0)
        });
    }

    function test_getOriginAmountOut_fromTKN() public {
        uint256 amount = 1 ether;
        address[] memory tokens = new address[](3);
        tokens[0] = ETH;
        tokens[1] = address(weth);
        tokens[2] = address(token);
        // Ask for TKN -> [ETH, WETH, TKN] quotes
        SwapQuery[] memory originQueries = router.getOriginAmountOut(address(token), tokens, amount);
        // End test prematurely if the returned array is not of length 3
        require(originQueries.length == 3, "Invalid array length");
        // First query: TKN -> ETH
        checkQueryWithAction({
            query: originQueries[0],
            token: ETH,
            amount: pool.calculateSwap(0, 1, amount),
            rawParams: getOriginSwapParams(0, 1)
        });
        // Second query: TKN -> WETH
        checkQueryWithAction({
            query: originQueries[1],
            token: address(weth),
            amount: pool.calculateSwap(0, 1, amount),
            rawParams: getOriginSwapParams(0, 1)
        });
        // Third query: TKN -> TKN
        checkQueryNoAction({query: originQueries[2], token: address(token), amount: amount});
    }
}
