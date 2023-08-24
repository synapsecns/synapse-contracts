// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockERC20, SynapseBridgeModuleTest} from "./SynapseBridgeModule.t.sol";

/// @notice Tests for SynapseBridge tokens that require a wrapper token
/// e.g. GMX on Avalanche
contract SynapseBridgeModuleWrappersTest is SynapseBridgeModuleTest {
    address public depositWrapperToken;
    address public redeemWrapperToken;

    function setUp() public virtual override {
        super.setUp();
        depositWrapperToken = address(new MockERC20("DWT", 18));
        redeemWrapperToken = address(new MockERC20("RWT", 18));
    }

    function addTokens() public virtual override {
        // Add both tokens, but use wrapper tokens for bridging
        addDepositToken("DT", depositToken, depositWrapperToken);
        addRedeemToken(
            "RT",
            redeemToken,
            redeemWrapperToken,
            DEFAULT_BRIDGE_FEE / 10,
            DEFAULT_MIN_FEE,
            DEFAULT_MAX_FEE
        );
    }

    // The tests are inherited from SynapseBridgeModuleTest, plus the ones below

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    // Concept of wrapper tokens is isolated within SynapseBridgeModule, so it should not be visible to the user

    function testGetMaxBridgedAmountReturnsZeroForWrapperToken() public {
        addTokens();
        assertEq(module.getMaxBridgedAmount(depositWrapperToken), 0);
        assertEq(module.getMaxBridgedAmount(redeemWrapperToken), 0);
    }

    function testCalculateFeeAmountRevertsForWrapperToken() public {
        addTokens();
        // Revert happens in LocalBridgeConfig.sol
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(depositWrapperToken, 0);
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(redeemWrapperToken, 0);
    }

    function testSymbolToTokenReturnsZeroForWrapperSymbol() public {
        addTokens();
        assertEq(module.symbolToToken("DWT"), address(0));
        assertEq(module.symbolToToken("RWT"), address(0));
    }

    function testTokenToSymbolReturnsEmptyStringForWrapperToken() public {
        addTokens();
        assertEq(module.tokenToSymbol(depositWrapperToken), "");
        assertEq(module.tokenToSymbol(redeemWrapperToken), "");
    }

    function testTokenToActionMaskReturnsZeroForWrapperToken() public {
        addTokens();
        assertEq(module.tokenToActionMask(depositWrapperToken), 0);
        assertEq(module.tokenToActionMask(redeemWrapperToken), 0);
    }
}
