// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    Action,
    BridgeToken,
    DefaultParams,
    SwapQuery,
    SynapseCCTPModule
} from "../../../../contracts/router/modules/bridge/SynapseCCTPModule.sol";
import {SynapseCCTP} from "../../../../contracts/cctp/SynapseCCTP.sol";

import {BaseCCTPTest} from "../../../cctp/BaseCCTP.t.sol";
import {DelegateCaller} from "./DelegateCaller.sol";

contract SynapseCCTPModuleTest is BaseCCTPTest {
    // 1M USDC
    uint256 public constant MAX_BURN_AMOUNT = 10**6 * 10**6;
    string public constant SYMBOL_USDC = "CCTP.MockC";

    SynapseCCTP public synapseCCTP;
    address public token;
    address public unknownToken;

    SynapseCCTPModule public module;
    DelegateCaller public delegateCaller;

    function setUp() public virtual override {
        super.setUp();
        setBurnLimitPerMessage(DOMAIN_ETH);

        synapseCCTP = synapseCCTPs[DOMAIN_ETH];
        token = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        // Use "MockT" token as the unknown token
        unknownToken = address(poolSetups[DOMAIN_ETH].token);

        delegateCaller = new DelegateCaller();
        module = new SynapseCCTPModule(address(synapseCCTP));
    }

    function setBurnLimitPerMessage(uint32 domain) public {
        cctpSetups[domain].tokenMinter.setBurnLimitPerMessage(
            address(cctpSetups[domain].mintBurnToken),
            MAX_BURN_AMOUNT
        );
    }

    function testConstructor() public {
        assertEq(module.synapseCCTP(), address(synapseCCTP));
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetMaxBridgedAmountReturnsMaxBurnAmountForSupportedToken() public {
        assertEq(module.getMaxBridgedAmount(token), MAX_BURN_AMOUNT);
    }

    function testGetMaxBridgedAmountReturnsZeroForUnsupportedToken() public {
        assertEq(module.getMaxBridgedAmount(unknownToken), 0);
    }

    // uint128 to prevent multiplication overflow in tests
    function testCalculateFeeAmountWhenSwap(uint128 amount) public {
        uint256 expectedFee = synapseCCTP.calculateFeeAmount(token, amount, true);
        assertEq(module.calculateFeeAmount(token, amount, true), expectedFee);
    }

    // uint128 to prevent multiplication overflow in tests
    function testCalculateFeeAmountWhenNoSwap(uint128 amount) public {
        uint256 expectedFee = synapseCCTP.calculateFeeAmount(token, amount, false);
        assertEq(module.calculateFeeAmount(token, amount, false), expectedFee);
    }

    function testCalculateFeeAmountRevertsForUnsupportedToken() public {
        bytes memory expectedError = abi.encodeWithSelector(
            SynapseCCTPModule.SynapseCCTPModule__UnsupportedToken.selector,
            unknownToken
        );
        vm.expectRevert(expectedError);
        module.calculateFeeAmount(unknownToken, 0, false);
        vm.expectRevert(expectedError);
        module.calculateFeeAmount(unknownToken, 0, true);
    }

    function testGetBridgeTokens() public {
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 1);
        assertEq(bridgeTokens[0].symbol, SYMBOL_USDC);
        assertEq(bridgeTokens[0].token, token);
    }

    function testGetBridgeTokensWhenZeroTokens() public {
        address cctpOwner = synapseCCTP.owner();
        vm.prank(cctpOwner);
        synapseCCTP.removeToken(token);
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 0);
    }

    function testSymbolToToken() public {
        assertEq(module.symbolToToken(SYMBOL_USDC), token);
    }

    function testSymbolToTokenReturnsZeroForUnknownSymbol() public {
        assertEq(module.symbolToToken("MockT"), address(0));
    }

    function testTokenToSymbol() public {
        assertEq(module.tokenToSymbol(token), SYMBOL_USDC);
    }

    function testTokenToSymbolReturnsEmptyStringForUnknownToken() public {
        assertEq(module.tokenToSymbol(unknownToken), "");
    }

    function testTokenToActionMask() public {
        uint256 expectedMask = 1 << uint256(Action.Swap);
        assertEq(module.tokenToActionMask(token), expectedMask);
    }

    function testTokenToActionMaskReturnsZeroForUnknownToken() public {
        assertEq(module.tokenToActionMask(unknownToken), 0);
    }
}
