// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouterV2} from "../../contracts/rfq/FastBridgeRouterV2.sol";

import {MockSenderContract} from "../mocks/MockSenderContract.sol";

import {FastBridgeRouterNativeTest, IFastBridge, SwapQuery} from "./FastBridgeRouter.Native.t.sol";

// solhint-disable not-rely-on-time
// solhint-disable ordering
// solhint-disable func-name-mixedcase
abstract contract FastBridgeRouterV2NativeTest is FastBridgeRouterNativeTest {
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

    // ════════════════════════════ TESTS: START FROM ETH (EOA, ORIGIN SENDER PROVIDED) ════════════════════════════════

    // Start from ETH, use ETH for RFQ
    function check_bridge_eth_noOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    // Start from ETH, use WETH for RFQ
    function check_bridge_eth_withOriginWrap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryWithHandleETH(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    // Start from ETH, use paired token for RFQ
    function check_bridge_eth_withOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: 0,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge{value: amountBeforeSwap}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    function test_bridge_eth_noOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_eth_noOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_eth_noOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_eth_noOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_eth_withOriginWrap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_eth_withOriginWrap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_eth_withOriginWrap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_eth_withOriginWrap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_eth_withOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_eth_withOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_eth_withOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_eth_withOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    // Note: Calls from EOA with origin sender set to zero address should succeed
    function test_bridge_eth_noOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_eth_noOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_eth_noOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_eth_noOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_eth_withOriginWrap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_eth_withOriginWrap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_eth_withOriginWrap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_eth_withOriginWrap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_eth_withOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_eth_withOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_eth_withOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_eth_withOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    // ═══════════════════════════ TESTS: START FROM WETH (EOA, ORIGIN SENDER PROVIDED) ════════════════════════════════

    // Start from WETH, use WETH for RFQ
    function check_bridge_weth_noOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
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
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    // Start from WETH, use ETH for RFQ
    function check_bridge_weth_withOriginUnwrap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryWithHandleETH(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    // Start from WETH, use paired token for RFQ
    function check_bridge_weth_withOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
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
            token: address(weth),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    function test_bridge_weth_noOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_weth_noOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_weth_noOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_weth_noOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_weth_withOriginUnwrap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_weth_withOriginUnwrap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_weth_withOriginUnwrap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_weth_withOriginUnwrap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_weth_withOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_weth_withOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_weth_withOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_weth_withOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    // Note: Calls from EOA with origin sender set to zero address should succeed
    function test_bridge_weth_noOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_weth_noOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_weth_noOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_weth_noOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_weth_withOriginUnwrap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_weth_withOriginUnwrap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_weth_withOriginUnwrap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_weth_withOriginUnwrap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_weth_withOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_weth_withOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_weth_withOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_weth_withOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    // ═══════════════════════ TESTS: START FROM PAIRED TOKEN (EOA, ORIGIN SENDER PROVIDED) ════════════════════════════

    // Start from paired token, use paired token for RFQ
    function check_bridge_token_noOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amount = 1 ether;
        SwapQuery memory originQuery = getOriginQueryNoSwap(address(token), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(token),
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
            token: address(token),
            amount: amount,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    // Start from paired token, use WETH for RFQ
    function check_bridge_token_withOriginSwap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(address(weth), amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: address(weth),
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
            token: address(token),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    // Start from paired token, use ETH for RFQ
    function check_bridge_token_withOriginSwapUnwrap(
        address caller,
        address originSender,
        bool gasRebate
    ) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        SwapQuery memory originQuery = getOriginQueryWithSwap(ETH, amount);
        IFastBridge.BridgeParams memory expectedParams = getExpectedBridgeParams({
            originToken: ETH,
            originAmount: amount,
            sendChainGas: gasRebate
        });
        vm.expectCall({
            callee: address(fastBridge),
            msgValue: amount,
            data: abi.encodeCall(IFastBridge.bridge, (expectedParams))
        });
        vm.prank(caller);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amountBeforeSwap,
            originQuery: originQuery,
            destQuery: gasRebate
                ? getDestQueryWithRebateWithOriginSender(amount, originSender)
                : getDestQueryNoRebateWithOriginSender(amount, originSender)
        });
    }

    function test_bridge_token_noOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_token_noOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_token_noOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_token_noOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_token_withOriginSwap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_token_withOriginSwap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_token_withOriginSwap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_token_withOriginSwap({caller: user, originSender: user, gasRebate: true});
    }

    function test_bridge_token_withOriginSwapUnwrap_noGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_token_withOriginSwapUnwrap({caller: user, originSender: user, gasRebate: false});
    }

    function test_bridge_token_withOriginSwapUnwrap_withGasRebate_senderEOA_withOriginSenderSet() public {
        check_bridge_token_withOriginSwapUnwrap({caller: user, originSender: user, gasRebate: true});
    }

    // Note: Calls from EOA with origin sender set to zero address should succeed
    function test_bridge_token_noOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_token_noOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_token_noOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_token_noOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_token_withOriginSwap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_token_withOriginSwap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_token_withOriginSwap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_token_withOriginSwap({caller: user, originSender: address(0), gasRebate: true});
    }

    function test_bridge_token_withOriginSwapUnwrap_noGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_token_withOriginSwapUnwrap({caller: user, originSender: address(0), gasRebate: false});
    }

    function test_bridge_token_withOriginSwapUnwrap_withGasRebate_senderEOA_withOriginSenderZero() public {
        check_bridge_token_withOriginSwapUnwrap({caller: user, originSender: address(0), gasRebate: true});
    }

    // ═════════════════════════ TESTS: START FROM ETH (CONTRACT, ORIGIN SENDER PROVIDED) ══════════════════════════════

    function test_bridge_eth_noOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_eth_noOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_eth_noOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_eth_noOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_eth_withOriginWrap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_eth_withOriginWrap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_eth_withOriginWrap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_eth_withOriginWrap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_eth_withOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_eth_withOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_eth_withOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_eth_withOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    // ═════════════════════════ TESTS: START FROM WETH (CONTRACT, ORIGIN SENDER PROVIDED) ═════════════════════════════

    function test_bridge_weth_noOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_weth_noOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_weth_noOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_weth_noOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_weth_withOriginUnwrap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_weth_withOriginUnwrap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_weth_withOriginUnwrap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_weth_withOriginUnwrap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_weth_withOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_weth_withOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_weth_withOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_weth_withOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    // ═════════════════════ TESTS: START FROM PAIRED TOKEN (CONTRACT, ORIGIN SENDER PROVIDED) ═════════════════════════

    function test_bridge_token_noOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_token_noOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_token_noOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_token_noOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_token_withOriginSwap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_token_withOriginSwap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_token_withOriginSwap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_token_withOriginSwap({caller: externalContract, originSender: user, gasRebate: true});
    }

    function test_bridge_token_withOriginSwapUnwrap_noGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_token_withOriginSwapUnwrap({caller: externalContract, originSender: user, gasRebate: false});
    }

    function test_bridge_token_withOriginSwapUnwrap_withGasRebate_senderContract_withOriginSenderSet() public {
        check_bridge_token_withOriginSwapUnwrap({caller: externalContract, originSender: user, gasRebate: true});
    }

    // ═══════════════════════ TESTS: START FROM ETH (CONTRACT, ORIGIN SENDER NOT PROVIDED) ════════════════════════════

    function check_bridge_eth_noOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: getOriginQueryNoSwap(ETH, amount),
            destQuery: destQuery
        });
    }

    function check_bridge_eth_withOriginWrap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge{value: amount}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amount,
            originQuery: getOriginQueryWithHandleETH(address(weth), amount),
            destQuery: destQuery
        });
    }

    function check_bridge_eth_withOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(1, 0, amountBeforeSwap);
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge{value: amountBeforeSwap}({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: ETH,
            amount: amountBeforeSwap,
            originQuery: getOriginQueryWithSwap(address(token), amount),
            destQuery: destQuery
        });
    }

    function test_bridge_eth_noOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_eth_noOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_eth_noOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_eth_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_eth_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_eth_withOriginWrap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_eth_withOriginWrap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_eth_withOriginWrap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_eth_withOriginWrap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_eth_withOriginWrap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_eth_withOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_eth_withOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_eth_withOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_eth_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_eth_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    // ═══════════════════════ TESTS: START FROM WETH (CONTRACT, ORIGIN SENDER NOT PROVIDED) ═══════════════════════════

    function check_bridge_weth_noOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: getOriginQueryNoSwap(address(weth), amount),
            destQuery: destQuery
        });
    }

    function check_bridge_weth_withOriginUnwrap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: getOriginQueryWithHandleETH(ETH, amount),
            destQuery: destQuery
        });
    }

    function check_bridge_weth_withOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(weth),
            amount: amount,
            originQuery: getOriginQueryWithSwap(address(token), amount),
            destQuery: destQuery
        });
    }

    function test_bridge_weth_noOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_weth_noOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_weth_noOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_weth_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_weth_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_weth_withOriginUnwrap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_weth_withOriginUnwrap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_weth_withOriginUnwrap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_weth_withOriginUnwrap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_weth_withOriginUnwrap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_weth_withOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_weth_withOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_weth_withOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_weth_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_weth_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    // ═══════════════════ TESTS: START FROM PAIRED TOKEN (CONTRACT, ORIGIN SENDER NOT PROVIDED) ═══════════════════════

    function check_bridge_token_noOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amount = 1 ether;
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amount,
            originQuery: getOriginQueryNoSwap(address(token), amount),
            destQuery: destQuery
        });
    }

    function check_bridge_token_withOriginSwap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amount,
            originQuery: getOriginQueryWithSwap(address(weth), amount),
            destQuery: destQuery
        });
    }

    function check_bridge_token_withOriginSwapUnwrap_senderContract_revert(SwapQuery memory destQuery) public {
        uint256 amountBeforeSwap = 1 ether;
        uint256 amount = pool.calculateSwap(0, 1, amountBeforeSwap);
        expectRevertOriginSenderNotSpecified();
        vm.prank(externalContract);
        router.bridge({
            recipient: recipient,
            chainId: DST_CHAIN_ID,
            token: address(token),
            amount: amount,
            originQuery: getOriginQueryWithSwap(ETH, amount),
            destQuery: destQuery
        });
    }

    function test_bridge_token_noOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_token_noOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_token_noOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_token_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_token_noOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_token_withOriginSwap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_token_withOriginSwap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_token_withOriginSwap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_token_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_token_withOriginSwap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }

    function test_bridge_token_withOriginSwapUnwrap_senderContract_reverts() public {
        // Revert when origin sender is not encoded into destQuery
        check_bridge_token_withOriginSwapUnwrap_senderContract_revert({destQuery: getDestQueryNoRebate(1 ether)});
        check_bridge_token_withOriginSwapUnwrap_senderContract_revert({destQuery: getDestQueryWithRebate(1 ether)});
        // Revert when empty origin sender is encoded into destQuery
        check_bridge_token_withOriginSwapUnwrap_senderContract_revert({
            destQuery: getDestQueryNoRebateWithOriginSender(1 ether, address(0))
        });
        check_bridge_token_withOriginSwapUnwrap_senderContract_revert({
            destQuery: getDestQueryWithRebateWithOriginSender(1 ether, address(0))
        });
    }
}
