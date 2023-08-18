// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OnlyDelegateCall} from "../pool/OnlyDelegateCall.sol";
import {IBridgeModule} from "../../interfaces/IBridgeModule.sol";
import {ILocalBridgeConfig} from "../../interfaces/ILocalBridgeConfig.sol";
import {Action, BridgeToken, SwapQuery} from "../../libs/Structs.sol";

contract SynapseBridgeModule is OnlyDelegateCall, IBridgeModule {
    /// These need to be immutable in order to be accessed via delegatecall
    ILocalBridgeConfig public immutable localBridgeConfig;
    address public immutable synapseBridge;

    constructor(address localBridgeConfig_, address synapseBridge_) {
        localBridgeConfig = ILocalBridgeConfig(localBridgeConfig_);
        synapseBridge = synapseBridge_;
    }

    /// @inheritdoc IBridgeModule
    function delegateBridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) external payable {
        assertDelegateCall();
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IBridgeModule
    function getMaxBridgedAmount(address token) external view returns (uint256 amount) {
        // Supported tokens don't have a max bridged amount
        (, address bridgeToken) = localBridgeConfig.config(token);
        if (bridgeToken != address(0)) {
            amount = type(uint256).max;
        }
        // Zero is returned for unsupported tokens
    }

    /// @inheritdoc IBridgeModule
    function calculateFeeAmount(address token, uint256 amount) external view returns (uint256 fee) {
        return localBridgeConfig.calculateBridgeFee(token, amount);
    }

    /// @inheritdoc IBridgeModule
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens) {
        // Get the list of token addresses from the local bridge config
        address[] memory tokens = localBridgeConfig.bridgeTokens();
        bridgeTokens = new BridgeToken[](tokens.length);
        // Get the symbol for each token
        for (uint256 i = 0; i < tokens.length; ++i) {
            bridgeTokens[i].symbol = localBridgeConfig.tokenToSymbol(tokens[i]);
            bridgeTokens[i].token = tokens[i];
        }
    }

    /// @inheritdoc IBridgeModule
    function symbolToToken(string memory symbol) external view returns (address token) {
        return localBridgeConfig.symbolToToken(symbol);
    }

    /// @inheritdoc IBridgeModule
    function tokenToSymbol(address token) external view returns (string memory symbol) {
        return localBridgeConfig.tokenToSymbol(token);
    }

    /// @inheritdoc IBridgeModule
    function tokenToActionMask(address token) external view returns (uint256 actionMask) {
        (ILocalBridgeConfig.TokenType tokenType, address bridgeToken) = localBridgeConfig.config(token);
        // Return empty mask if token is not supported
        if (bridgeToken == address(0)) return 0;
        // Return mask of available actions for the token, when it is bridged TO THIS chain.
        if (tokenType == ILocalBridgeConfig.TokenType.Redeem) {
            // Txs with redeemed tokens are completed on THIS chain by:
            // - synapseBridge.mint(): no Action is taken
            // - synapseBridge.mintAndSwap(): Action.Swap is taken
            // Therefore, the only available action is Swap
            return Action.Swap.mask();
        } else {
            // Txs with deposited tokens are completed on THIS chain by:
            // - synapseBridge.withdraw(): no Action is taken
            // - synapseBridge.withdrawAndRemove(): Action.RemoveLiquidity is taken
            // Also, if WETH is withdrawn, it gets unwrapped to ETH by the bridge.
            // Therefore, the only available actions are RemoveLiquidity and HandleEth
            return Action.RemoveLiquidity.mask(Action.HandleEth);
        }
    }
}
