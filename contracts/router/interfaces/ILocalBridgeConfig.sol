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

    /**
     * @notice Struct defining a supported bridge token. This is not supposed to be stored on-chain,
     * so this is not optimized in terms of storage words.
     * @param id            ID for token used in BridgeConfigV3
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param decimals      Amount ot decimals used for `token`
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    struct BridgeTokenConfig {
        string id;
        address token;
        uint256 decimals;
        TokenType tokenType;
        address bridgeToken;
        uint256 bridgeFee;
        uint256 minFee;
        uint256 maxFee;
    }

    // ══════════════════════════════════════════════ STORAGE WRITES ═══════════════════════════════════════════════════

    /**
     * @notice Adds a bridge token and its fee structure to the local config, if it was not added before.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     * @return wasAdded     True, if token was added to the config
     */
    function addToken(
        string memory symbol,
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) external returns (bool wasAdded);

    /// @notice Adds a bunch of bridge tokens and their fee structure to the local config, if it was not added before.
    function addTokens(BridgeTokenConfig[] memory tokens) external;

    /**
     * @notice Updates the bridge config for an already added bridge token.
     * @dev Will revert if token was not added before.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     */
    function setTokenConfig(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) external;

    /**
     * @notice Updates the fee structure for an already added bridge token.
     * @dev Will revert if token was not added before.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    function setTokenFee(
        address token,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) external;

    /**
     * @notice Removes tokens from the local config, and deletes the associated bridge fee structure.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for removing.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @return wasRemoved   True, if token was removed from the config
     */
    function removeToken(address token) external returns (bool wasRemoved);

    /**
     * @notice Removes a list of tokens from the local config, and deletes their associated bridge fee structure.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for removing.
     * @param tokens    List of "end" tokens, supported by SynapseBridge. These are the tokens user is receiving/sending.
     */
    function removeTokens(address[] calldata tokens) external;

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
