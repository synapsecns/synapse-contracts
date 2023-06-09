// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    CCTPIncorrectConfig,
    CCTPInsufficientAmount,
    CCTPSymbolAlreadyAdded,
    CCTPSymbolIncorrect,
    CCTPTokenAlreadyAdded,
    CCTPTokenNotFound
} from "../../../contracts/cctp/libs/Errors.sol";
import {BridgeToken, SynapseCCTPFees} from "../../../contracts/cctp/fees/SynapseCCTPFees.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable-next-line no-empty-blocks
contract SynapseCCTPFeesHarness is SynapseCCTPFees {
    /// @notice Exposes the internal `_applyRelayerFee` function for testing purposes
    function applyRelayerFee(
        address token,
        uint256 amount,
        bool isSwap
    ) external returns (uint256 amountAfterFee, uint256 fee) {
        return _applyRelayerFee(token, amount, isSwap);
    }
}

contract SynapseCCTPFeesTest is Test {
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

    function testApplyRelayerFeeUpdatesAccumulatedFees() public {
        addTokens();
        // Check Min Fee
        checkAccumulatedFees(usdc, 10**9, false, 1 * 10**6);
        checkAccumulatedFees(usdc, 10**9, true, 5 * 10**6);
        checkAccumulatedFees(eurc, 10**9, false, 2 * 10**6);
        checkAccumulatedFees(eurc, 10**9, true, 10 * 10**6);
        // Check Max Fee
        checkAccumulatedFees(usdc, 10**12, false, 100 * 10**6);
        checkAccumulatedFees(usdc, 10**12, true, 100 * 10**6);
        checkAccumulatedFees(eurc, 10**12, false, 50 * 10**6);
        checkAccumulatedFees(eurc, 10**12, true, 50 * 10**6);
        // Check Percentage Fee
        checkAccumulatedFees(usdc, 10**10, false, 5 * 10**6);
        checkAccumulatedFees(usdc, 2 * 10**10, true, 10 * 10**6);
        checkAccumulatedFees(eurc, 10**10, false, 10 * 10**6);
        checkAccumulatedFees(eurc, 2 * 10**10, true, 20 * 10**6);
    }

    function checkBridgeFeeValues(
        address token,
        uint256 amount,
        bool isSwap,
        uint256 expectedFee
    ) public {
        (uint256 amountAfterFee, uint256 fee) = cctpFees.applyRelayerFee(token, amount, isSwap);
        assertEq(amountAfterFee, amount - fee);
        assertEq(fee, expectedFee);
    }

    function checkAccumulatedFees(
        address token,
        uint256 amount,
        bool isSwap,
        uint256 expectedFee
    ) public {
        uint256 accumulatedFeesBefore = cctpFees.accumulatedFees(token);
        cctpFees.applyRelayerFee(token, amount, isSwap);
        uint256 accumulatedFeesAfter = cctpFees.accumulatedFees(token);
        assertEq(accumulatedFeesAfter - accumulatedFeesBefore, expectedFee);
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
}
