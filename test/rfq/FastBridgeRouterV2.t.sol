// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DeadlineExceeded, InsufficientOutputAmount} from "../../contracts/router/DefaultRouter.sol";
import {FastBridgeRouterV2} from "../../contracts/rfq/FastBridgeRouterV2.sol";

import {MockSenderContract} from "../mocks/MockSenderContract.sol";

import {FastBridgeRouterTest, IFastBridge, SwapQuery} from "./FastBridgeRouter.t.sol";

// solhint-disable not-rely-on-time
// solhint-disable ordering
// solhint-disable func-name-mixedcase
abstract contract FastBridgeRouterV2Test is FastBridgeRouterTest {
    address public externalContract;

    function setUp() public virtual override {
        super.setUp();
        externalContract = address(new MockSenderContract());
        prepareAccount(externalContract);
    }

    function deployRouter() public virtual override returns (address payable) {
        return payable(new FastBridgeRouterV2(owner));
    }

    function getDestQueryNoRebateWithOriginSender(uint256 amount, address originSender)
        public
        view
        returns (SwapQuery memory destQuery)
    {
        destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amount - FIXED_FEE,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: abi.encodePacked(uint8(0), originSender)
        });
    }

    function getDestQueryWithRebateWithOriginSender(uint256 amount, address originSender)
        public
        view
        returns (SwapQuery memory destQuery)
    {
        destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amount - FIXED_FEE,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: abi.encodePacked(REBATE_FLAG, originSender)
        });
    }

    function expectRevertOriginSenderNotSpecified() public {
        vm.expectRevert(FastBridgeRouterV2.FastBridgeRouterV2__OriginSenderNotSpecified.selector);
    }

    // ════════════════════════════════ TESTS: BRIDGE (EOA, ORIGIN SENDER PROVIDED) ════════════════════════════════════

    function check_bridge_noOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token0),
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    function check_bridge_withOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token1),
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    function test_bridge_noOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_noOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_noOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_noOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_withOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_withOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_withOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_withOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    // Note: Calls from EOA with origin sender set to zero address should succeed
    function test_bridge_noOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_noOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_noOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_noOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_withOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_withOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_withOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_withOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    // ═════════════════════════════ TESTS: BRIDGE (CONTRACT, ORIGIN SENDER PROVIDED) ══════════════════════════════════

    function test_bridge_noOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_noOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_noOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_noOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_withOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_withOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_withOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_withOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    // ═══════════════════════════ TESTS: BRIDGE (CONTRACT, ORIGIN SENDER NOT PROVIDED) ════════════════════════════════

    function check_bridge_noOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(amount);
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function check_bridge_withOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount);
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token0),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_bridge_noOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_noOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_noOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_withOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_withOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_withOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    // ═══════════════════════════════════════════════ MISC REVERTS ════════════════════════════════════════════════════

    function test_bridge_noOriginSwap_revert_deadlineExceeded() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(amount);
        originQuery.deadline = block.timestamp - 1;
        vm.expectRevert(DeadlineExceeded.selector);
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

    function test_bridge_withOriginSwap_revert_deadlineExceeded() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount);
        originQuery.deadline = block.timestamp - 1;
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

    function test_bridge_noOriginSwap_revert_insufficientOutputAmount() public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(amount);
        originQuery.minAmountOut = amount + 1;
        vm.expectRevert(InsufficientOutputAmount.selector);
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

    function test_bridge_withOriginSwap_revert_insufficientOutputAmount() public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(amount);
        originQuery.minAmountOut = amount + 1;
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
}
