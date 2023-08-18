// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OnlyDelegateCall} from "../pool/OnlyDelegateCall.sol";
import {IBridgeModule} from "../../interfaces/IBridgeModule.sol";
import {ILocalBridgeConfig} from "../../interfaces/ILocalBridgeConfig.sol";
import {ISynapseBridge} from "../../interfaces/ISynapseBridge.sol";
import {Action, BridgeToken, DefaultParams, SwapQuery} from "../../libs/Structs.sol";

contract SynapseBridgeModule is OnlyDelegateCall, IBridgeModule {
    /// These need to be immutable in order to be accessed via delegatecall
    ILocalBridgeConfig public immutable localBridgeConfig;
    ISynapseBridge public immutable synapseBridge;

    constructor(address localBridgeConfig_, address synapseBridge_) {
        localBridgeConfig = ILocalBridgeConfig(localBridgeConfig_);
        synapseBridge = ISynapseBridge(synapseBridge_);
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
        ILocalBridgeConfig.TokenType tokenType;
        // Use config.bridgeToken as the token address for the bridging purposes
        (tokenType, token) = localBridgeConfig.config(token);
        require(token != address(0), "Token not supported");
        if (destQuery.routerAdapter == address(0)) {
            // If no Router Adapter is set, no action is required on destination chain, use `deposit()` or `redeem()`
            (tokenType == ILocalBridgeConfig.TokenType.Redeem ? synapseBridge.redeem : synapseBridge.deposit)(
                to,
                chainId,
                token,
                amount
            );
        } else {
            // Otherwise, use tokenType-dependent internal function to give destination chain action instructions
            (tokenType == ILocalBridgeConfig.TokenType.Redeem ? _redeemTokenWithAction : _depositTokenWithAction)(
                to,
                chainId,
                token,
                amount,
                destQuery
            );
        }
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

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Initiates a bridging transaction for a token that requires a deposit on this chain
    /// and an action on the destination chain.
    function _depositTokenWithAction(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) internal {
        // Decode the params for the destination chain otherwise
        DefaultParams memory params = abi.decode(destQuery.rawParams, (DefaultParams));
        // Token is deposited on THIS chain => it is minted on the destination chain.
        // Minting of token is done by calling destination synapseBridge:
        // - mint(): no Action is taken
        // - mintAndSwap(): Action.Swap is taken
        // Therefore, the only available action is Swap
        if (params.action == Action.Swap) {
            // Give instructions for swap on destination chain => `depositAndSwap()`
            synapseBridge.depositAndSwap({
                to: to,
                chainId: chainId,
                token: token,
                amount: amount,
                tokenIndexFrom: params.tokenIndexFrom,
                tokenIndexTo: params.tokenIndexTo,
                minDy: destQuery.minAmountOut,
                deadline: destQuery.deadline
            });
        } else {
            revert("Unsupported dest action");
        }
    }

    /// @dev Initiates a bridging transaction for a token that requires a redeem on this chain
    /// and an action on the destination chain.
    function _redeemTokenWithAction(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) internal {
        // Decode the params for the destination chain otherwise
        DefaultParams memory params = abi.decode(destQuery.rawParams, (DefaultParams));
        // Token is redeemed on THIS chain => it could be either minted and withdrawn on the destination chain.
        // Minting of token is done by calling destination synapseBridge:
        // - mint(): no Action is taken
        // - mintAndSwap(): Action.Swap is taken
        // Withdrawing of token is done by calling destination synapseBridge:
        // - withdraw(): no Action is taken
        // - withdrawAndRemove(): Action.RemoveLiquidity is taken
        // Also, if WETH is withdrawn, it gets unwrapped to ETH by the bridge.
        // Therefore, the available actions are Swap, RemoveLiquidity and HandleEth
        if (params.action == Action.Swap) {
            // Give instructions for swap on destination chain => `redeemAndSwap()`
            synapseBridge.redeemAndSwap({
                to: to,
                chainId: chainId,
                token: token,
                amount: amount,
                tokenIndexFrom: params.tokenIndexFrom,
                tokenIndexTo: params.tokenIndexTo,
                minDy: destQuery.minAmountOut,
                deadline: destQuery.deadline
            });
        } else if (params.action == Action.RemoveLiquidity) {
            // Give instructions for removing liquidity on destination chain => `redeemAndRemove()`
            synapseBridge.redeemAndRemove({
                to: to,
                chainId: chainId,
                token: token,
                amount: amount,
                liqTokenIndex: params.tokenIndexTo,
                liqMinAmount: destQuery.minAmountOut,
                liqDeadline: destQuery.deadline
            });
        } else if (params.action == Action.HandleEth) {
            // Handle ETH on destination chain is done natively by SynapseBridge => `redeem()`
            synapseBridge.redeem(to, chainId, token, amount);
        } else {
            revert("Unsupported dest action");
        }
    }
}
