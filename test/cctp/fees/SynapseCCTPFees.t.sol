// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    CastOverflow,
    CCTPGasRescueFailed,
    CCTPIncorrectConfig,
    CCTPIncorrectProtocolFee,
    CCTPInsufficientAmount,
    CCTPSymbolAlreadyAdded,
    CCTPSymbolIncorrect,
    CCTPTokenAlreadyAdded,
    CCTPTokenNotFound
} from "../../../contracts/cctp/libs/Errors.sol";
import {BridgeToken, SynapseCCTPFees, SynapseCCTPFeesEvents} from "../../../contracts/cctp/fees/SynapseCCTPFees.sol";

import {MockRevertingRecipient} from "../../mocks/MockRevertingRecipient.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable-next-line no-empty-blocks
contract SynapseCCTPFeesHarness is SynapseCCTPFees {
    receive() external payable {}

    /// @notice Exposes the internal `_applyRelayerFee` function for testing purposes
    function applyRelayerFee(
        address token,
        uint256 amount,
        bool isSwap
    ) external returns (uint256 amountAfterFee, uint256 fee) {
        return _applyRelayerFee(token, amount, isSwap);
    }

    /// @notice Exposes the internal `_transferMsgValue` function for testing purposes
    function transferMsgValue(address recipient) external payable {
        _transferMsgValue(recipient);
    }
}

contract SynapseCCTPFeesTest is SynapseCCTPFeesEvents, Test {
    SynapseCCTPFeesHarness public cctpFees;
    address public owner;
    address public usdc;
    address public eurc;

    function setUp() public {
        cctpFees = new SynapseCCTPFeesHarness();
        owner = makeAddr("Owner");
        cctpFees.transferOwnership(owner);
        usdc = makeAddr("USDC");
        eurc = makeAddr("EURC");
    }

    function testSetup() public {
        assertEq(cctpFees.owner(), owner);
        assertEq(cctpFees.getBridgeTokens().length, 0);
        assertEq(cctpFees.protocolFee(), 0);
        assertEq(cctpFees.chainGasAmount(), 0);
    }

    // ═══════════════════════════════════════════ TESTS: ADDING TOKENS ════════════════════════════════════════════════

    function addTokens() public {
        // add USDC: 5bp relayer fee, 1 USDC min base fee, 5 USDC min swap fee, 100 USDC max fee
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", usdc, 5 * 10**6, 1 * 10**6, 5 * 10**6, 100 * 10**6);
        // add EURC: 10bp relayer fee, 2 EURC min base fee, 10 EURC min swap fee, 50 EURC max fee
        vm.prank(owner);
        cctpFees.addToken("CCTP.EURC", eurc, 10 * 10**6, 2 * 10**6, 10 * 10**6, 50 * 10**6);
    }

    function testAddTokenSavesBridgeTokensList() public {
        addTokens();
        BridgeToken[] memory tokens = cctpFees.getBridgeTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0].symbol, "CCTP.USDC");
        assertEq(tokens[0].token, usdc);
        assertEq(tokens[1].symbol, "CCTP.EURC");
        assertEq(tokens[1].token, eurc);
    }

    function testAddTokenSavesFeeStructure() public {
        addTokens();
        (uint256 relayerFee, uint256 minBaseFee, uint256 minSwapFee, uint256 maxFee) = cctpFees.feeStructures(usdc);
        assertEq(relayerFee, 5 * 10**6);
        assertEq(minBaseFee, 1 * 10**6);
        assertEq(minSwapFee, 5 * 10**6);
        assertEq(maxFee, 100 * 10**6);
        (relayerFee, minBaseFee, minSwapFee, maxFee) = cctpFees.feeStructures(eurc);
        assertEq(relayerFee, 10 * 10**6);
        assertEq(minBaseFee, 2 * 10**6);
        assertEq(minSwapFee, 10 * 10**6);
        assertEq(maxFee, 50 * 10**6);
    }

    function testAddTokenSavesTokenAddress() public {
        addTokens();
        assertEq(cctpFees.tokenToSymbol(usdc), "CCTP.USDC");
        assertEq(cctpFees.tokenToSymbol(eurc), "CCTP.EURC");
    }

    function testAddTokenSavesTokenSymbol() public {
        addTokens();
        assertEq(cctpFees.symbolToToken("CCTP.USDC"), usdc);
        assertEq(cctpFees.symbolToToken("CCTP.EURC"), eurc);
    }

    function testAddTokenRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        cctpFees.addToken("CCTP.USDC", address(1), 0, 0, 0, 0);
    }

    function testAddTokenRevertsWhenSymbolAlreadyAdded() public {
        addTokens();
        vm.expectRevert(CCTPSymbolAlreadyAdded.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 0, 0, 0);
    }

    function checkAddIncorrectSymbol(string memory symbol) public {
        vm.expectRevert(CCTPSymbolIncorrect.selector);
        vm.prank(owner);
        cctpFees.addToken(symbol, address(1), 0, 0, 0, 0);
    }

    function testAddTokenRevertsWhenSymbolPrefixIncorrect() public {
        checkAddIncorrectSymbol("CCTP-Token");
        checkAddIncorrectSymbol("CCTp.Token");
        checkAddIncorrectSymbol("CCtP.Token");
        checkAddIncorrectSymbol("CcTP.Token");
        checkAddIncorrectSymbol("cCTP.Token");
    }

    function testAddTokenRevertsWhenSymbolTooShort() public {
        checkAddIncorrectSymbol("CCTP.");
        checkAddIncorrectSymbol("CCTP");
        checkAddIncorrectSymbol("CCT");
        checkAddIncorrectSymbol("CC");
        checkAddIncorrectSymbol("C");
        checkAddIncorrectSymbol("");
    }

    function testAddTokenRevertsWhenTokenAlreadyAdded() public {
        addTokens();
        vm.expectRevert(CCTPTokenAlreadyAdded.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC-new", usdc, 0, 0, 0, 0);
    }

    function testAddTokenRevertsWhenTokenAddressZero() public {
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(0), 0, 0, 0, 0);
    }

    function testAddTokenRevertsBridgeFeeTooHigh() public {
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        // A bit over 10 bps
        cctpFees.addToken("CCTP.USDC", address(1), 10**7 + 1, 0, 0, 0);
    }

    function testAddTokenRevertsMinBaseFeeHigherThanMinSwapFee() public {
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 10, 9, 100);
    }

    function testAddTokenRevertsMinSwapFeeHigherThanMaxFee() public {
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 10, 11, 10);
    }

    function testAddTokenRevertsRelayerFeeOverflows() public {
        // Check that relayer fee % is not too high is failed prior to casting to uint40
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 2**40, 0, 0, 0);
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), type(uint256).max, 0, 0, 0);
    }

    function testAddTokenRevertsMinBaseFeeOverflows() public {
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 2**72, 2**72, 2**72);
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, type(uint256).max, type(uint256).max, type(uint256).max);
    }

    function testAddTokenRevertsMinSwapFeeOverflows() public {
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 0, 2**72, 2**72);
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 0, type(uint256).max, type(uint256).max);
    }

    function testAddTokenRevertsMaxFeeOverflows() public {
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 0, 0, 2**72);
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.addToken("CCTP.USDC", address(1), 0, 0, 0, type(uint256).max);
    }

    // ══════════════════════════════════════════ TESTS: REMOVING TOKENS ═══════════════════════════════════════════════

    function addTokensThenRemoveOne() public {
        addTokens();
        vm.prank(owner);
        cctpFees.removeToken(usdc);
    }

    function testRemoveTokenUpdatesBridgeTokensList() public {
        addTokensThenRemoveOne();
        BridgeToken[] memory tokens = cctpFees.getBridgeTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0].symbol, "CCTP.EURC");
        assertEq(tokens[0].token, eurc);
    }

    function testRemoveTokenClearsFeeStructure() public {
        addTokensThenRemoveOne();
        (uint256 relayerFee, uint256 minBaseFee, uint256 minSwapFee, uint256 maxFee) = cctpFees.feeStructures(usdc);
        assertEq(relayerFee, 0);
        assertEq(minBaseFee, 0);
        assertEq(minSwapFee, 0);
        assertEq(maxFee, 0);
    }

    function testRemoveTokenClearsTokenAddress() public {
        addTokensThenRemoveOne();
        assertEq(cctpFees.tokenToSymbol(usdc), "");
    }

    function testRemoveTokenClearsTokenSymbol() public {
        addTokensThenRemoveOne();
        assertEq(cctpFees.symbolToToken("CCTP.USDC"), address(0));
    }

    function testRemoveTokenRevertsWhenCallerNotOwner(address caller) public {
        addTokens();
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        cctpFees.removeToken(usdc);
    }

    function testRemoveTokenRevertsWhenTokenNotFound() public {
        vm.expectRevert(CCTPTokenNotFound.selector);
        vm.prank(owner);
        cctpFees.removeToken(usdc);
    }

    // ════════════════════════════════════════ TESTS: UPDATING TOKEN FEES ═════════════════════════════════════════════

    function testSetTokenFee() public {
        addTokens();
        // New fees: 1bp relayer fee, 2 USDC min base fee, 3 USDC min swap fee, 4 USDC max fee
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 1 * 10**6, 2 * 10**6, 3 * 10**6, 4 * 10**6);
        (uint256 relayerFee, uint256 minBaseFee, uint256 minSwapFee, uint256 maxFee) = cctpFees.feeStructures(usdc);
        assertEq(relayerFee, 1 * 10**6);
        assertEq(minBaseFee, 2 * 10**6);
        assertEq(minSwapFee, 3 * 10**6);
        assertEq(maxFee, 4 * 10**6);
    }

    function testSetTokenFeeRevertsWhenCallerNotOwner(address caller) public {
        addTokens();
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        cctpFees.setTokenFee(usdc, 0, 0, 0, 0);
    }

    function testSetTokenFeeRevertsWhenTokenNotFound() public {
        vm.expectRevert(CCTPTokenNotFound.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 0, 0, 0);
    }

    function testSetTokenFeeRevertsWhenBridgeFeeTooHigh() public {
        addTokens();
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        // A bit over 10 bps
        cctpFees.setTokenFee(usdc, 10**7 + 1, 0, 0, 0);
    }

    function testSetTokenFeeRevertsWhenMinBaseFeeHigherThanMinSwapFee() public {
        addTokens();
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 10, 9, 100);
    }

    function testSetTokenFeeRevertsWhenMinSwapFeeHigherThanMaxFee() public {
        addTokens();
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 10, 11, 10);
    }

    function testSetTokenFeeRevertsRelayerFeeOverflows() public {
        // Check that relayer fee % is not too high is failed prior to casting to uint40
        addTokens();
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 2**40, 0, 0, 0);
        vm.expectRevert(CCTPIncorrectConfig.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, type(uint256).max, 0, 0, 0);
    }

    function testSetTokenFeeRevertsMinBaseFeeOverflows() public {
        addTokens();
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 2**72, 2**72, 2**72);
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, type(uint256).max, type(uint256).max, type(uint256).max);
    }

    function testSetTokenFeeRevertsMinSwapFeeOverflows() public {
        addTokens();
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 0, 2**72, 2**72);
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 0, type(uint256).max, type(uint256).max);
    }

    function testSetTokenFeeRevertsMaxFeeOverflows() public {
        addTokens();
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 0, 0, 2**72);
        vm.expectRevert(CastOverflow.selector);
        vm.prank(owner);
        cctpFees.setTokenFee(usdc, 0, 0, 0, type(uint256).max);
    }

    // ══════════════════════════════════════ TESTS: CALCULATING BRIDGE FEES ═══════════════════════════════════════════

    function testCalculateFeeAmountReturnsMinFee() public {
        addTokens();
        assertEq(cctpFees.calculateFeeAmount(usdc, 10**9, false), 1 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(usdc, 10**9, true), 5 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(eurc, 10**9, false), 2 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(eurc, 10**9, true), 10 * 10**6);
    }

    function testCalculateFeeAmountReturnsMaxFee() public {
        addTokens();
        assertEq(cctpFees.calculateFeeAmount(usdc, 10**12, false), 100 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(usdc, 10**12, true), 100 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(eurc, 10**12, false), 50 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(eurc, 10**12, true), 50 * 10**6);
    }

    function testCalculateFeeAmountReturnsCorrectPercentageFee() public {
        addTokens();
        // USDC fee is 5bps
        assertEq(cctpFees.calculateFeeAmount(usdc, 10**10, false), 5 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(usdc, 2 * 10**10, true), 10 * 10**6);
        // EURC fee is 10bps
        assertEq(cctpFees.calculateFeeAmount(eurc, 10**10, false), 10 * 10**6);
        assertEq(cctpFees.calculateFeeAmount(eurc, 2 * 10**10, true), 20 * 10**6);
    }

    // ══════════════════════════════════════════ TESTS: COLLECTING FEES ═══════════════════════════════════════════════

    function testApplyRelayerFeeReturnsCorrectValues() public {
        addTokens();
        // Check Min Fee
        checkBridgeFeeValues(usdc, 10**9, false, 1 * 10**6);
        checkBridgeFeeValues(usdc, 10**9, true, 5 * 10**6);
        checkBridgeFeeValues(eurc, 10**9, false, 2 * 10**6);
        checkBridgeFeeValues(eurc, 10**9, true, 10 * 10**6);
        // Check Max Fee
        checkBridgeFeeValues(usdc, 10**12, false, 100 * 10**6);
        checkBridgeFeeValues(usdc, 10**12, true, 100 * 10**6);
        checkBridgeFeeValues(eurc, 10**12, false, 50 * 10**6);
        checkBridgeFeeValues(eurc, 10**12, true, 50 * 10**6);
        // Check Percentage Fee
        checkBridgeFeeValues(usdc, 10**10, false, 5 * 10**6);
        checkBridgeFeeValues(usdc, 2 * 10**10, true, 10 * 10**6);
        checkBridgeFeeValues(eurc, 10**10, false, 10 * 10**6);
        checkBridgeFeeValues(eurc, 2 * 10**10, true, 20 * 10**6);
    }

    function testApplyRelayerFeeUpdatesAccumulatedFeesCollectorNotSet() public {
        addTokens();
        applyRelayerFeeScenarios(makeAddr("Relayer"), address(0));
    }

    function testApplyRelayerFeeUpdatesAccumulatedFeesCollectorNotSetWithProtocolFee() public {
        addTokens();
        vm.prank(owner);
        // 10% protocol fee
        cctpFees.setProtocolFee(10**9);
        // Collector is not set, so the whole fee goes to the protocol
        applyRelayerFeeScenarios(makeAddr("Relayer"), address(0));
    }

    function testApplyRelayerFeeUpdatesAccumulatedFeesCollectorSet() public {
        addTokens();
        address relayer = makeAddr("Relayer");
        address collector = makeAddr("Collector");
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector);
        applyRelayerFeeScenarios(relayer, collector);
    }

    function testApplyRelayerFeeUpdatesAccumulatedFeesCollectorSetWithProtocolFee() public {
        addTokens();
        address relayer = makeAddr("Relayer");
        address collector = makeAddr("Collector");
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector);
        vm.prank(owner);
        // 10% protocol fee
        cctpFees.setProtocolFee(10**9);
        applyRelayerFeeScenariosWithProtocolFee(relayer, collector);
    }

    function applyRelayerFeeScenarios(address relayer, address collector) public {
        // Check Min Fee
        checkAccumulatedFees(usdc, 10**9, false, 1 * 10**6, relayer, collector);
        checkAccumulatedFees(usdc, 10**9, true, 5 * 10**6, relayer, collector);
        checkAccumulatedFees(eurc, 10**9, false, 2 * 10**6, relayer, collector);
        checkAccumulatedFees(eurc, 10**9, true, 10 * 10**6, relayer, collector);
        // Check Max Fee
        checkAccumulatedFees(usdc, 10**12, false, 100 * 10**6, relayer, collector);
        checkAccumulatedFees(usdc, 10**12, true, 100 * 10**6, relayer, collector);
        checkAccumulatedFees(eurc, 10**12, false, 50 * 10**6, relayer, collector);
        checkAccumulatedFees(eurc, 10**12, true, 50 * 10**6, relayer, collector);
        // Check Percentage Fee
        checkAccumulatedFees(usdc, 10**10, false, 5 * 10**6, relayer, collector);
        checkAccumulatedFees(usdc, 2 * 10**10, true, 10 * 10**6, relayer, collector);
        checkAccumulatedFees(eurc, 10**10, false, 10 * 10**6, relayer, collector);
        checkAccumulatedFees(eurc, 2 * 10**10, true, 20 * 10**6, relayer, collector);
    }

    function applyRelayerFeeScenariosWithProtocolFee(address relayer, address collector) public {
        // Protocol fee is set to 10%
        // Check Min Fee
        checkAccumulatedFeesWithProtocolFee(usdc, 10**9, false, 1 * 10**6, 1 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(usdc, 10**9, true, 5 * 10**6, 5 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(eurc, 10**9, false, 2 * 10**6, 2 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(eurc, 10**9, true, 10 * 10**6, 10 * 10**5, relayer, collector);
        // Check Max Fee
        checkAccumulatedFeesWithProtocolFee(usdc, 10**12, false, 100 * 10**6, 100 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(usdc, 10**12, true, 100 * 10**6, 100 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(eurc, 10**12, false, 50 * 10**6, 50 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(eurc, 10**12, true, 50 * 10**6, 50 * 10**5, relayer, collector);
        // Check percentage fee
        checkAccumulatedFeesWithProtocolFee(usdc, 10**10, false, 5 * 10**6, 5 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(usdc, 2 * 10**10, true, 10 * 10**6, 10 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(eurc, 10**10, false, 10 * 10**6, 10 * 10**5, relayer, collector);
        checkAccumulatedFeesWithProtocolFee(eurc, 2 * 10**10, true, 20 * 10**6, 20 * 10**5, relayer, collector);
    }

    function checkBridgeFeeValues(
        address token,
        uint256 amount,
        bool isSwap,
        uint256 expectedFee
    ) public {
        vm.expectEmit();
        // Full fee goes to protocol
        emit FeeCollected({feeCollector: address(0), relayerFeeAmount: 0, protocolFeeAmount: expectedFee});
        (uint256 amountAfterFee, uint256 fee) = cctpFees.applyRelayerFee(token, amount, isSwap);
        assertEq(amountAfterFee, amount - fee);
        assertEq(fee, expectedFee);
    }

    function checkAccumulatedFees(
        address token,
        uint256 amount,
        bool isSwap,
        uint256 expectedFee,
        address relayer,
        address collector
    ) public {
        uint256 accumulatedFeesBefore = cctpFees.accumulatedFees(collector, token);
        vm.expectEmit();
        // Full fee goes to relayer if they specified a collector
        // Otherwise, full fee goes to protocol
        emit FeeCollected({
            feeCollector: collector,
            relayerFeeAmount: collector == address(0) ? 0 : expectedFee,
            protocolFeeAmount: collector == address(0) ? expectedFee : 0
        });
        vm.prank(relayer);
        cctpFees.applyRelayerFee(token, amount, isSwap);
        uint256 accumulatedFeesAfter = cctpFees.accumulatedFees(collector, token);
        assertEq(accumulatedFeesAfter - accumulatedFeesBefore, expectedFee);
    }

    function checkAccumulatedFeesWithProtocolFee(
        address token,
        uint256 amount,
        bool isSwap,
        uint256 expectedTotalFee,
        uint256 expectedProtocolFee,
        address relayer,
        address collector
    ) public {
        uint256 protocolFeesBefore = cctpFees.accumulatedFees(address(0), token);
        uint256 accumulatedFeesBefore = cctpFees.accumulatedFees(collector, token);
        vm.expectEmit();
        // Fee is split between protocol and relayer
        emit FeeCollected({
            feeCollector: collector,
            relayerFeeAmount: expectedTotalFee - expectedProtocolFee,
            protocolFeeAmount: expectedProtocolFee
        });
        vm.prank(relayer);
        cctpFees.applyRelayerFee(token, amount, isSwap);
        uint256 protocolFeesAfter = cctpFees.accumulatedFees(address(0), token);
        assertEq(protocolFeesAfter - protocolFeesBefore, expectedProtocolFee);
        uint256 accumulatedFeesAfter = cctpFees.accumulatedFees(collector, token);
        assertEq(accumulatedFeesAfter - accumulatedFeesBefore, expectedTotalFee - expectedProtocolFee);
    }

    function testApplyRelayerFeeRevertsWhenTokenNotFound() public {
        vm.expectRevert(CCTPTokenNotFound.selector);
        cctpFees.applyRelayerFee(usdc, 10**9, false);
        vm.expectRevert(CCTPTokenNotFound.selector);
        cctpFees.applyRelayerFee(eurc, 10**9, true);
    }

    function testApplyRelayerFeeRevertsWhenAmountInsufficientBaseRequest() public {
        addTokens();
        // Set amount equal to min base fee
        vm.expectRevert(CCTPInsufficientAmount.selector);
        cctpFees.applyRelayerFee(usdc, 1 * 10**6, false);
        vm.expectRevert(CCTPInsufficientAmount.selector);
        cctpFees.applyRelayerFee(eurc, 2 * 10**6, false);
    }

    function testApplyRelayerFeeRevertsWhenAmountInsufficientSwapRequest() public {
        addTokens();
        // Set amount equal to min swap fee
        vm.expectRevert(CCTPInsufficientAmount.selector);
        cctpFees.applyRelayerFee(usdc, 5 * 10**6, true);
        vm.expectRevert(CCTPInsufficientAmount.selector);
        cctpFees.applyRelayerFee(eurc, 10 * 10**6, true);
    }

    // ═══════════════════════════════════════ TESTS: SETTING FEE COLLECTOR ════════════════════════════════════════════

    function testSetFeeCollectorFirstCallSetsCollector() public {
        address relayer = makeAddr("Relayer");
        address collector = makeAddr("Collector");
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector);
        assertEq(cctpFees.relayerFeeCollectors(relayer), collector);
    }

    function testSetFeeCollectorFirstCallEmitsEvent() public {
        address relayer = makeAddr("Relayer");
        address collector = makeAddr("Collector");
        vm.expectEmit();
        emit FeeCollectorUpdated(relayer, address(0), collector);
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector);
    }

    function testSetFeeCollectorSubsequentCallUpdatesCollector() public {
        address relayer = makeAddr("Relayer");
        address collector0 = makeAddr("Collector 0");
        address collector1 = makeAddr("Collector 1");
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector0);
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector1);
        assertEq(cctpFees.relayerFeeCollectors(relayer), collector1);
    }

    function testSetFeeCollectorSubsequentCallEmitsEvent() public {
        address relayer = makeAddr("Relayer");
        address collector0 = makeAddr("Collector 0");
        address collector1 = makeAddr("Collector 1");
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector0);
        vm.expectEmit();
        emit FeeCollectorUpdated(relayer, collector0, collector1);
        vm.prank(relayer);
        cctpFees.setFeeCollector(collector1);
    }

    function testSetFeeCollectorDifferentRelayers() public {
        address relayer0 = makeAddr("Relayer 0");
        address relayer1 = makeAddr("Relayer 1");
        address collector0 = makeAddr("Collector 0");
        address collector1 = makeAddr("Collector 1");
        address collector2 = makeAddr("Collector 2");
        vm.prank(relayer0);
        cctpFees.setFeeCollector(collector0);
        vm.prank(relayer1);
        cctpFees.setFeeCollector(collector0);
        vm.prank(relayer0);
        cctpFees.setFeeCollector(collector1);
        vm.prank(relayer1);
        cctpFees.setFeeCollector(collector2);
        assertEq(cctpFees.relayerFeeCollectors(relayer0), collector1);
        assertEq(cctpFees.relayerFeeCollectors(relayer1), collector2);
    }

    // ════════════════════════════════════════════ TESTS: PROTOCOL FEE ════════════════════════════════════════════════

    function testSetProtocolFeeUpdatesProtocolFee() public {
        // Set initial protocol fee
        vm.prank(owner);
        cctpFees.setProtocolFee(10**9);
        assertEq(cctpFees.protocolFee(), 10**9);
        // Update protocol fee
        vm.prank(owner);
        cctpFees.setProtocolFee(5 * 10**9);
        assertEq(cctpFees.protocolFee(), 5 * 10**9);
    }

    function testSetProtocolFeeEmitsEvent() public {
        // Set initial protocol fee
        vm.expectEmit();
        emit ProtocolFeeUpdated(10**9);
        vm.prank(owner);
        cctpFees.setProtocolFee(10**9);
        // Update protocol fee
        vm.expectEmit();
        emit ProtocolFeeUpdated(5 * 10**9);
        vm.prank(owner);
        cctpFees.setProtocolFee(5 * 10**9);
    }

    function testSetProtocolFeeRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        cctpFees.setProtocolFee(10**9);
    }

    function testSetProtocolFeeRevertsWhenProtocolFeeTooHigh() public {
        vm.expectRevert(CCTPIncorrectProtocolFee.selector);
        vm.prank(owner);
        cctpFees.setProtocolFee(5 * 10**9 + 1);
    }

    // ════════════════════════════════════════ TESTS: SETTING GAS AIRDROP ═════════════════════════════════════════════

    function testSetChainGasAmountSetsValue() public {
        // Set initial chain gas amount
        vm.prank(owner);
        cctpFees.setChainGasAmount(10**9);
        assertEq(cctpFees.chainGasAmount(), 10**9);
        // Update chain gas amount
        vm.prank(owner);
        cctpFees.setChainGasAmount(5 * 10**9);
        assertEq(cctpFees.chainGasAmount(), 5 * 10**9);
    }

    function testSetChainGasAmountEmitsEvent() public {
        // Set initial chain gas amount
        vm.expectEmit();
        emit ChainGasAmountUpdated(10**9);
        vm.prank(owner);
        cctpFees.setChainGasAmount(10**9);
        // Update chain gas amount
        vm.expectEmit();
        emit ChainGasAmountUpdated(5 * 10**9);
        vm.prank(owner);
        cctpFees.setChainGasAmount(5 * 10**9);
    }

    function testSetChainGasAmountRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        cctpFees.setChainGasAmount(10**9);
    }

    // ════════════════════════════════════════ TESTS: TRANSFER GAS AIRDROP ════════════════════════════════════════════

    function testTransferMsgValueTransfersGas() public {
        uint256 amount = 10**9;
        address relayer = makeAddr("Relayer");
        address recipient = makeAddr("Recipient");
        deal(relayer, amount);
        vm.prank(relayer);
        cctpFees.transferMsgValue{value: amount}(recipient);
        assertEq(recipient.balance, amount);
    }

    function testTransferMsgValueEmitsEvent() public {
        uint256 amount = 10**9;
        address relayer = makeAddr("Relayer");
        address recipient = makeAddr("Recipient");
        deal(relayer, amount);
        vm.expectEmit();
        emit ChainGasAirdropped(amount);
        vm.prank(relayer);
        cctpFees.transferMsgValue{value: amount}(recipient);
    }

    function testTransferMsgValueWhenRecipientReverted() public {
        uint256 amount = 10**9;
        address relayer = makeAddr("Relayer");
        address recipient = address(new MockRevertingRecipient());
        deal(relayer, amount);
        vm.expectEmit();
        emit ChainGasAirdropped(0);
        vm.prank(relayer);
        cctpFees.transferMsgValue{value: amount}(recipient);
        assertEq(address(cctpFees).balance, amount);
    }

    // ════════════════════════════════════════════ TESTS: RESCUING GAS ════════════════════════════════════════════════

    function testRescueGasTransfersGas() public {
        uint256 amount = 10**9;
        deal(address(cctpFees), amount);
        vm.prank(owner);
        cctpFees.rescueGas();
        assertEq(owner.balance, amount);
    }

    function testRescueGasRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        cctpFees.rescueGas();
    }

    function testRescueGasRevertsWhenOwnerReverts() public {
        uint256 amount = 10**9;
        deal(address(cctpFees), amount);
        address revertingOwner = address(new MockRevertingRecipient());
        vm.prank(owner);
        cctpFees.transferOwnership(revertingOwner);
        vm.expectRevert(CCTPGasRescueFailed.selector);
        vm.prank(revertingOwner);
        cctpFees.rescueGas();
    }
}
