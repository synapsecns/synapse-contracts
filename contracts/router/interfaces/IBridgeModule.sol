// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BridgeToken, SwapQuery} from "../libs/Structs.sol";

interface IBridgeModule {
    /// @notice Performs a bridging transaction on behalf of the sender, assuming they already have `token`.
    /// @dev This will be used via delegatecall from SynapseRouterV2, which will have custody over the bridge tokens.
    /// This will revert if delegatecall is not used.
    /// @param to            Address to receive tokens on destination chain
    /// @param chainId       Destination chain id
    /// @param token         Address of the bridge token
    /// @param amount        Amount of the tokens for the bridge transaction
    /// @param destQuery     Destination swap query. Empty struct indicates no swap is required
    function delegateBridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) external payable;

    /// @notice Gets the maximum amount of tokens user can bridge from this chain.
    /// @param token        Address of the bridge token
    /// @return amount      Max amount of tokens user can bridge from this chain
    function getMaxBridgedAmount(address token) external view returns (uint256 amount);

    /// @notice Calculates the fee amount for bridging a token to this chain.
    /// @dev Will revert if the token is not supported.
    /// @param token        Address of the bridge token
    /// @param amount       Amount of tokens to be bridged
    /// @param isSwap       Whether the user provided swap details for converting the bridge token
    ///                     to the final token on this chain
    /// @return fee         Fee amount
    function calculateFeeAmount(
        address token,
        uint256 amount,
        bool isSwap
    ) external view returns (uint256 fee);

    /// @notice Returns the list of all supported bridge tokens and their bridge symbols.
    /// - Bridge symbol is consistent across all chains for a given token and their bridge.
    /// - Bridge symbol doesn't have to be the same as the token symbol on this chain.
    /// @return bridgeTokens Supported bridge tokens and their bridge symbols
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens);

    /// @notice Returns the address of the bridge token for a given bridge symbol.
    /// - Bridge symbol is consistent across all chains for a given token and their bridge.
    /// - Bridge symbol doesn't have to be the same as the token symbol on this chain.
    /// @dev Will return address(0) if the token is not supported.
    /// @param symbol       Symbol of the supported bridge token used by the token's bridge
    /// @return token       Address of the bridge token
    function symbolToToken(string memory symbol) external view returns (address token);

    /// @notice Returns the bridge symbol of a given bridge token.
    /// - Bridge symbol is consistent across all chains for a given token and their bridge.
    /// - Bridge symbol doesn't have to be the same as the token symbol on this chain.
    /// @dev Will return empty string if the token is not supported.
    /// @param token        Address of the bridge token
    /// @return symbol      Symbol of the supported bridge token used by the token's bridge
    function tokenToSymbol(address token) external view returns (string memory symbol);

    /// @notice Returns the action mask associated with bridging a token to this chain.
    /// Action mask is a bitmask of the actions that could be performed with the token atomically with the
    /// incoming bridge transaction to this chain. See Structs.sol for the list of actions.
    /// @dev Will return 0 (empty mask) if the token is not supported.
    /// @param token        Address of the bridge token
    /// @return actionMask  Action mask for the bridge token
    function tokenToActionMask(address token) external view returns (uint256 actionMask);
}
