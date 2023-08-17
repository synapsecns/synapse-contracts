// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libs/Structs.sol";

interface IBridgeModule {
    /// @notice Performs a bridging transaction on behalf of the sender, assuming `token` is already in the contract.
    /// @dev This will be used via delegatecall from SynapseRotuerV2, which will have custody over the initial tokens.
    /// @param to            Address to receive tokens on destination chain
    /// @param chainId       Destination chain id
    /// @param token         Initial token for the bridge transaction to be pulled from the user
    /// @param amount        Amount of the initial tokens for the bridge transaction
    /// @param destQuery     Destination swap query. Empty struct indicates no swap is required
    function delegateBridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) external payable;

    /// @notice Gets the maximum amount of tokens user can bridge
    /// @param token        Address of the bridging token
    /// @return amount      Max amount of tokens user can bridge
    function getMaxBridgedAmount(address token) external view returns (uint256 amount);

    /// @notice Calculates the fee amount for bridging a token to this chain.
    /// @param token        Address of the bridging token
    /// @param amount       Amount of tokens to be bridged
    /// @return fee         Fee amount
    function calculateFeeAmount(address token, uint256 amount) external view returns (uint256 fee);

    /// @notice Returns the list of all supported bridge tokens and their symbols.
    /// @return bridgeTokens Supported bridge tokens and their symbols
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens);

    /// @notice Returns the address of the bridge token for a given symbol.
    /// @dev Will return address(0) if the token is not supported.
    /// @param symbol       Symbol of the supported bridging token
    /// @return token       Address of the bridging token
    function symbolToToken(string memory symbol) external view returns (address token);

    /// @notice Returns the symbol of a given bridge token.
    /// @dev Will return empty string if the token is not supported.
    /// @param token        Address of the bridging token
    /// @return symbol      Symbol of the supported bridging token
    function tokenToSymbol(address token) external view returns (string memory symbol);
}
