// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract LocalBridgeConfig is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

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
     * @param tokenType     Method of bridging used for the token: Redeem or Deposit.
     * @param bridgeToken   Actual token used for bridging `token`. This is the token bridge is burning/locking.
     *                      Might differ from `token`, if `token` does not conform to bridge-supported interface.
     * @param bridgeFee     Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
     * @param minFee        Minimum fee for bridging a token to this chain, in token decimals
     * @param maxFee        Maximum fee for bridging a token to this chain, in token decimals
     */
    struct BridgeToken {
        string id;
        address token;
        LocalBridgeConfig.TokenType tokenType;
        address bridgeToken;
        uint256 bridgeFee;
        uint256 minFee;
        uint256 maxFee;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Denominator used to calculate the bridge fee: amount.mul(bridgeFee).div(FEE_DENOMINATOR)
    uint256 private constant FEE_DENOMINATOR = 10**10;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Config for each supported token.
    /// @dev If wrapper token is required for bridging, its address is stored in `.bridgeToken`
    /// i.e. for GMX: config[GMX].bridgeToken = GMXWrapper
    mapping(address => TokenConfig) public config;
    /// @notice Fee structure for each supported token.
    /// @dev If wrapper token is required for bridging, its underlying is used as key here
    mapping(address => FeeStructure) public fee;
    /// @dev A list of all supported bridge tokens
    EnumerableSet.AddressSet internal _bridgeTokens;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

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
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) external onlyOwner returns (bool wasAdded) {
        wasAdded = _addToken(token, tokenType, bridgeToken, bridgeFee, minFee, maxFee);
    }

    /// @notice Adds a bunch of bridge tokens and their fee structure to the local config, if it was not added before.
    function addTokens(BridgeToken[] memory tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            BridgeToken memory token = tokens[i];
            _addToken(token.token, token.tokenType, token.bridgeToken, token.bridgeFee, token.minFee, token.maxFee);
        }
    }

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
    ) external onlyOwner {
        require(config[token].bridgeToken != address(0), "Unknown token");
        _setTokenConfig(token, tokenType, bridgeToken);
    }

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
    ) external onlyOwner {
        require(config[token].bridgeToken != address(0), "Unknown token");
        _setTokenFee(token, bridgeFee, minFee, maxFee);
    }

    /**
     * @notice Removes tokens from the local config, and deletes the associated bridge fee structure.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for removing.
     * @param token         "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @return wasRemoved   True, if token was removed from the config
     */
    function removeToken(address token) external onlyOwner returns (bool wasRemoved) {
        wasRemoved = _removeToken(token);
    }

    /**
     * @notice Removes a list of tokens from the local config, and deletes their associated bridge fee structure.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for removing.
     * @param tokens    List of "end" tokens, supported by SynapseBridge. These are the tokens user is receiving/sending.
     */
    function removeTokens(address[] calldata tokens) external onlyOwner {
        uint256 amount = tokens.length;
        for (uint256 i = 0; i < amount; ++i) {
            _removeToken(tokens[i]);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns a list of all supported bridge tokens.
    function bridgeTokens() external view returns (address[] memory tokens) {
        uint256 amount = bridgeTokensAmount();
        tokens = new address[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            tokens[i] = _bridgeTokens.at(i);
        }
    }

    /// @notice Returns the amount of the supported bridge tokens.
    function bridgeTokensAmount() public view returns (uint256 amount) {
        amount = _bridgeTokens.length();
    }

    /**
     * @notice Calculates a fee for bridging a token to this chain.
     * @dev If a token requires a bridge wrapper token, use the underlying token address for getting a fee quote.
     * @param token     "End" token, supported by SynapseBridge. This is the token user is receiving/sending.
     * @param amount    Amount of tokens to bridge to this chain.
     */
    function calculateBridgeFee(address token, uint256 amount) external view returns (uint256 feeAmount) {
        feeAmount = _calculateBridgeFee(token, amount);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 INTERNAL: ADD & REMOVE BRIDGE TOKENS                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Adds a bridge token config, if it's not present and updates its fee structure.
    /// Child contract could implement additional logic upon adding a token.
    function _addToken(
        address token,
        TokenType tokenType,
        address bridgeToken,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) internal virtual returns (bool wasAdded) {
        wasAdded = _bridgeTokens.add(token);
        if (wasAdded) {
            // Need to save config only once
            _setTokenConfig(token, tokenType, bridgeToken);
            _setTokenFee(token, bridgeFee, minFee, maxFee);
        }
    }

    /// @dev Updates the token config for an already known bridge token.
    function _setTokenConfig(
        address token,
        TokenType tokenType,
        address bridgeToken
    ) internal {
        // Sanity checks for the provided token values
        require(token != address(0) && bridgeToken != address(0), "Token can't be zero address");
        config[token] = TokenConfig(tokenType, bridgeToken);
    }

    /// @dev Updates the fee structure for an already known bridge token.
    function _setTokenFee(
        address token,
        uint256 bridgeFee,
        uint256 minFee,
        uint256 maxFee
    ) internal {
        // Sanity checks for the provided fee values
        require(bridgeFee < FEE_DENOMINATOR, "bridgeFee >= 100%");
        require(minFee <= maxFee, "minFee > maxFee");
        fee[token] = FeeStructure(uint40(bridgeFee), uint104(minFee), uint112(maxFee));
    }

    /// @dev Removes a bridge token config along with its fee structure.
    /// Child contract could implement additional logic upon removing a token.
    function _removeToken(address token) internal virtual returns (bool wasRemoved) {
        wasRemoved = _bridgeTokens.remove(token);
        if (wasRemoved) {
            delete config[token];
            delete fee[token];
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL: VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the amount of tokens received after applying the bridge fee.
    /// Will return 0, if bridged amount is lower than a minimum bridge fee.
    function _calculateBridgeAmountOut(address token, uint256 amount) internal view returns (uint256 amountOut) {
        uint256 feeAmount = _calculateBridgeFee(token, amount);
        if (feeAmount < amount) {
            // No need for SafeMath here
            amountOut = amount - feeAmount;
        }
        // Return 0, if fee amount >= amount
    }

    /// @dev Returns the fee for bridging a given token to this chain.
    function _calculateBridgeFee(address token, uint256 amount) internal view returns (uint256 feeAmount) {
        require(config[token].bridgeToken != address(0), "Token not supported");
        FeeStructure memory tokenFee = fee[token];
        feeAmount = amount.mul(tokenFee.bridgeFee).div(FEE_DENOMINATOR);
        if (feeAmount < tokenFee.minFee) {
            feeAmount = tokenFee.minFee;
        } else if (feeAmount > tokenFee.maxFee) {
            feeAmount = tokenFee.maxFee;
        }
    }
}
