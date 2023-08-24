// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    Action,
    BridgeToken,
    SynapseBridgeModule
} from "../../../../contracts/router/modules/bridge/SynapseBridgeModule.sol";

import {MockERC20} from "../../mocks/MockERC20.sol";

import {DelegateCaller} from "./DelegateCaller.sol";
import {SynapseBridgeUtils} from "./SynapseBridgeUtils.sol";

contract SynapseBridgeModuleTest is SynapseBridgeUtils {
    SynapseBridgeModule public module;
    DelegateCaller public delegateCaller;

    address public depositToken;
    address public redeemToken;
    address public unknownToken;

    function setUp() public virtual override {
        super.setUp();
        delegateCaller = new DelegateCaller();
        module = new SynapseBridgeModule({
            localBridgeConfig_: address(localBridgeConfig),
            synapseBridge_: synapseBridge
        });
        depositToken = address(new MockERC20("DT", 18));
        redeemToken = address(new MockERC20("RT", 18));
        unknownToken = address(new MockERC20("UT", 18));
    }

    function testConstructor() public {
        assertEq(address(module.localBridgeConfig()), address(localBridgeConfig));
        assertEq(address(module.synapseBridge()), synapseBridge);
    }

    function addTokens() public virtual {
        addDepositToken("DT", depositToken);
        addRedeemToken("RT", redeemToken, DEFAULT_BRIDGE_FEE / 10, DEFAULT_MIN_FEE, DEFAULT_MAX_FEE);
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetMaxBridgedAmountReturnsMaxForSupportedToken() public {
        addTokens();
        assertEq(module.getMaxBridgedAmount(depositToken), type(uint256).max);
        assertEq(module.getMaxBridgedAmount(redeemToken), type(uint256).max);
    }

    function testGetMaxBridgedAmountReturnsZeroForUnsupportedToken() public {
        addTokens();
        assertEq(module.getMaxBridgedAmount(unknownToken), 0);
    }

    // uint128 to prevent multiplication overflow in tests
    function testCalculateFeeAmount(uint128 amount) public {
        addTokens();
        uint256 expectedDepositTokenFee = localBridgeConfig.calculateBridgeFee(depositToken, amount);
        uint256 expectedRedeemTokenFee = localBridgeConfig.calculateBridgeFee(redeemToken, amount);
        assertEq(module.calculateFeeAmount(depositToken, amount), expectedDepositTokenFee);
        assertEq(module.calculateFeeAmount(redeemToken, amount), expectedRedeemTokenFee);
    }

    function testCalculateFeeAmountRevertsForUnsupportedToken() public {
        addTokens();
        // Revert happens in LocalBridgeConfig.sol
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(unknownToken, 0);
    }

    function testGetBridgeTokens() public {
        addTokens();
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 2);
        assertEq(bridgeTokens[0].symbol, "DT");
        assertEq(bridgeTokens[0].token, depositToken);
        assertEq(bridgeTokens[1].symbol, "RT");
        assertEq(bridgeTokens[1].token, redeemToken);
    }

    function testGetBridgeTokensWhenZeroTokens() public {
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 0);
    }

    function testSymbolToToken() public {
        addTokens();
        assertEq(module.symbolToToken("DT"), depositToken);
        assertEq(module.symbolToToken("RT"), redeemToken);
    }

    function testSymbolToTokenReturnsZeroForUnknownSymbol() public {
        assertEq(module.symbolToToken("UT"), address(0));
    }

    function testTokenToSymbol() public {
        addTokens();
        assertEq(module.tokenToSymbol(depositToken), "DT");
        assertEq(module.tokenToSymbol(redeemToken), "RT");
    }

    function testTokenToSymbolReturnsEmptyStringForUnknownToken() public {
        assertEq(module.tokenToSymbol(unknownToken), "");
    }

    function testTokenToActionMaskDepositToken() public {
        addTokens();
        uint256 expectedMask = (1 << uint256(Action.RemoveLiquidity)) | (1 << uint256(Action.HandleEth));
        assertEq(module.tokenToActionMask(depositToken), expectedMask);
    }

    function testTokenToActionMaskRedeemToken() public {
        addTokens();
        uint256 expectedMask = 1 << uint256(Action.Swap);
        assertEq(module.tokenToActionMask(redeemToken), expectedMask);
    }

    function testTokenToActionMaskReturnsZeroForUnknownToken() public {
        assertEq(module.tokenToActionMask(unknownToken), 0);
    }
}
