// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IFastBridge, SwapQuery} from "../../contracts/rfq/FastBridgeRouter.sol";
import {DeadlineExceeded, InsufficientOutputAmount} from "../../contracts/router/libs/Errors.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockDefaultPool} from "../mocks/MockDefaultPool.sol";

import {FBRTest} from "./FBRTest.sol";

abstract contract FastBridgeRouterTest is FBRTest {
    MockERC20 public token0;
    MockERC20 public token1;

    event FastBridgeSet(address newFastBridge);
    event SwapQuoterSet(address newSwapQuoter);

    function setUp() public virtual override {
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
        prepareAccount(user);
        setUpSwapQuoter();
    }

    function prepareAccount(address account) public {
        token0.mint(account, 10 ether);
        token1.mint(account, 10 ether);
        vm.prank(account);
        token0.approve(address(router), 10 ether);
        vm.prank(account);
        token1.approve(address(router), 10 ether);
    }

    function setUpSwapQuoter() internal virtual;

    function getOriginQueryNoSwap(uint256 amount) public view returns (SwapQuery memory originQuery) {
        originQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: address(token0),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: ""
        });
    }

    function getOriginQueryWithSwap(uint256 amount) public view returns (SwapQuery memory originQuery) {
        originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token1),
            minAmountOut: amount,
            deadline: block.timestamp,
            rawParams: getOriginSwapParams(0, 1)
        });
    }

    // ══════════════════════════════════════════ TESTS: SET FAST BRIDGE ═══════════════════════════════════════════════

    function test_setFastBridge_setsFastBridge() public {
        address newFastBridge = address(0x123);
        vm.prank(owner);
        router.setFastBridge(newFastBridge);
        assertEq(router.fastBridge(), newFastBridge);
    }

    function test_setFastBridge_emitsEvent() public {
        address newFastBridge = address(0x123);
        vm.expectEmit(address(router));
        emit FastBridgeSet(newFastBridge);
        vm.prank(owner);
        router.setFastBridge(newFastBridge);
    }

    function test_setFastBridge_revert_whenNotOwner() public {
        address newFastBridge = address(0x123);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        router.setFastBridge(newFastBridge);
    }

    // ══════════════════════════════════════════ TESTS: SET SWAP QUOTER ═══════════════════════════════════════════════

    function test_setSwapQuoter_setsSwapQuoter() public {
        address newSwapQuoter = address(0x123);
        vm.prank(owner);
        router.setSwapQuoter(newSwapQuoter);
        assertEq(router.swapQuoter(), newSwapQuoter);
    }

    function test_setSwapQuoter_emitsEvent() public {
        address newSwapQuoter = address(0x123);
        vm.expectEmit(address(router));
        emit SwapQuoterSet(newSwapQuoter);
        vm.prank(owner);
        router.setSwapQuoter(newSwapQuoter);
    }

    function test_setSwapQuoter_revert_whenNotOwner() public {
        address newSwapQuoter = address(0x123);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        router.setSwapQuoter(newSwapQuoter);
    }

    // ═══════════════════════════════════════════════ TESTS: BRIDGE ═══════════════════════════════════════════════════

    function test_bridge_noOriginSwap_noGasRebate_senderEOA() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token0),
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
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_noOriginSwap_withGasRebate_senderEOA() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token0),
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
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    function test_bridge_withOriginSwap_noGasRebate_senderEOA() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token1),
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
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryNoRebate(amount)
        });
    }

    function test_bridge_withOriginSwap_withGasRebate_senderEOA() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token1),
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
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: getDestQueryWithRebate(amount)
        });
    }

    // ══════════════════════════════════════════════ TESTS: REVERTS ═══════════════════════════════════════════════════

    function test_bridge_revert_originSwap_deadlineExceeded() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: address(token1),
            minAmountOut: amount,
            deadline: block.timestamp - 1,
            rawParams: getOriginSwapParams(0, 1)
        });
        vm.expectRevert(DeadlineExceeded.selector);
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

    function test_bridge_revert_originSwap_minAmountOutNotMet() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount + 1);
        vm.expectRevert(InsufficientOutputAmount.selector);
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

    // ═══════════════════════════════════════ TESTS: GET ORIGIN AMOUNT OUT ════════════════════════════════════════════

    function test_getOriginAmountOut() public {
        address[] memory rfqTokens = new address[](2);
        rfqTokens[0] = address(token0);
        rfqTokens[1] = address(token1);
        // Ask for token0 -> [token0, token1] quotes
        SwapQuery[] memory originQueries = router.getOriginAmountOut(address(token0), rfqTokens, 1 ether);
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
