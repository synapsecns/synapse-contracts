// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseBridgeModuleTest} from "./SynapseBridgeModule.t.sol";
import {MockWrapperToken} from "../../mocks/MockWrapperToken.sol";

/// @notice Tests for SynapseBridge tokens that require a wrapper token
/// e.g. GMX on Avalanche
contract SynapseBridgeModuleWrappersTest is SynapseBridgeModuleTest {
    address public depositWrapperToken;
    address public redeemWrapperToken;

    function setUp() public virtual override {
        super.setUp();
        depositWrapperToken = address(new MockWrapperToken(depositToken));
        redeemWrapperToken = address(new MockWrapperToken(redeemToken));
        vm.label(depositWrapperToken, "DWT");
        vm.label(redeemWrapperToken, "RWT");
        // Approve spending of wrapper tokens on behalf of the delegate caller
        // In practice, this would be done by SynapseRouter.setAllowance()
        vm.startPrank(address(delegateCaller));
        MockWrapperToken(depositWrapperToken).approve(synapseBridge, type(uint256).max);
        MockWrapperToken(redeemWrapperToken).approve(synapseBridge, type(uint256).max);
        vm.stopPrank();
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

    // Wrapper test should override this function
    function getBridgeToken(address token) public view virtual override returns (address) {
        if (token == depositToken) return depositWrapperToken;
        if (token == redeemToken) return redeemWrapperToken;
        revert("Token not supported");
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
        module.calculateFeeAmount(depositWrapperToken, 0, false);
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(depositWrapperToken, 0, true);
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(redeemWrapperToken, 0, false);
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(redeemWrapperToken, 0, true);
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
