// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILocalBridgeConfig {
    /**
     * @notice Indicates the type of the supported bridge token on the local chain.
     * - TokenType.Redeem: token is burnt in order to initiate a bridge tx (bridge.redeem)
     * - TokenType.Deposit: token is locked in order to initiate a bridge tx (bridge.deposit)
     */
    enum TokenType {
        Redeem,
        Deposit
    }

    /**
     * @notice Config for a supported bridge token.
     * @dev Some of the tokens require a wrapper token to make them conform SynapseERC20 interface.
     * In these cases, `bridgeToken` will feature a different address.
     * Otherwise, the token address is saved.
     * @param tokenType     Method of bridging for the token: Redeem or Deposit
     * @param bridgeToken   Bridge token address
     */
    struct TokenConfig {
        TokenType tokenType;
        address bridgeToken;
    }

    /**
     * @notice Fee structure for a supported bridge token, optimized to fit in a single storage word.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    struct FeeStructure {
        uint40 bridgeFee;
        uint104 minFee;
        uint112 maxFee;
    }

    // ═══════════════════════════════════════════════ STORAGE VIEWS ═══════════════════════════════════════════════════

    /// @notice Config for each supported token.
    /// @dev If wrapper token is required for bridging, its address is stored in `.bridgeToken`
    /// i.e. for GMX: config[GMX].bridgeToken = GMXWrapper
    function config(address token) external view returns (TokenType tokenType, address bridgeToken);

    /// @notice Fee structure for each supported token.
    /// @dev If wrapper token is required for bridging, its underlying is used as key here
    function fee(address token)
        external
        view
        returns (
            uint40 bridgeFee,
            uint104 minFee,
            uint112 maxFee
        );

    /// @notice Maps bridge token address into bridge token symbol
    function tokenToSymbol(address token) external view returns (string memory symbol);

    /// @notice Maps bridge token symbol into bridge token address
    function symbolToToken(string memory symbol) external view returns (address token);

    // ════════════════════════════════════════════════ OTHER VIEWS ════════════════════════════════════════════════════

    /// @notice Returns a list of all supported bridge tokens.
    function bridgeTokens() external view returns (address[] memory tokens);

    /// @notice Returns the amount of the supported bridge tokens.
    function bridgeTokensAmount() external view returns (uint256 amount);

    /**
     * @notice Calculates a fee for bridging a token to this chain.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for getting a fee quote.
     * @param token     "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param amount    Amount of tokens to bridge to this chain.
     */
    function calculateBridgeFee(address token, uint256 amount) external view returns (uint256 feeAmount);
}
