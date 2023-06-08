// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CCTPSymbolAlreadyAdded, CCTPSymbolIncorrect, CCTPTokenAlreadyAdded, CCTPTokenNotFound} from "../libs/Errors.sol";
import {TypeCasts} from "../libs/TypeCasts.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableSet.sol";

abstract contract SynapseCCTPFees is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using TypeCasts for uint256;

    /// @notice CCTP fee structure for a supported Circle token.
    /// @dev Optimized for storage. 2**72 is 4*10**21, which is enough to represent adequate amounts
    /// for stable coins with 18 decimals. Circle tokens have 6 decimals, so this is more than enough.
    /// @param relayerFee   Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @param minBaseFee   Minimum fee for bridging a token to this chain using a base request
    /// @param minSwapFee   Minimum fee for bridging a token to this chain using a swap request
    /// @param maxFee       Maximum fee for bridging a token to this chain
    struct CCTPFee {
        uint40 relayerFee;
        uint72 minBaseFee;
        uint72 minSwapFee;
        uint72 maxFee;
    }

    /// @dev Denominator used to calculate the bridge fee
    uint256 private constant FEE_DENOMINATOR = 10**10;
    /// @dev Mandatory prefix used for CCTP token symbols to distinguish them from other bridge symbols
    bytes private constant SYMBOL_PREFIX = "CCTP.";
    /// @dev Length of the mandatory prefix used for CCTP token symbols
    uint256 private constant SYMBOL_PREFIX_LENGTH = 5;

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    /// @notice Maps bridge token address into bridge token symbol
    mapping(address => string) public tokenToSymbol;
    /// @notice Maps bridge token symbol into bridge token address
    mapping(string => address) public symbolToToken;
    /// @dev Maps bridge token address into CCTP fee structure
    mapping(address => CCTPFee) internal _tokenFees;
    /// @dev A list of all supported bridge tokens
    EnumerableSet.AddressSet internal _bridgeTokens;

    // ════════════════════════════════════════════════ ONLY OWNER ═════════════════════════════════════════════════════

    /// @notice Adds a new token to the list of supported tokens, with the given symbol and fee structure.
    /// @dev The symbol must start with "CCTP."
    /// @param symbol       Symbol of the token
    /// @param token        Address of the token
    /// @param relayerFee   Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @param minBaseFee   Minimum fee for bridging a token to this chain using a base request
    /// @param minSwapFee   Minimum fee for bridging a token to this chain using a swap request
    /// @param maxFee       Maximum fee for bridging a token to this chain
    function addToken(
        string memory symbol,
        address token,
        uint256 relayerFee,
        uint256 minBaseFee,
        uint256 minSwapFee,
        uint256 maxFee
    ) external onlyOwner {
        // Add a new token to the list of supported tokens, and check that it hasn't been added before
        if (!_bridgeTokens.add(token)) revert CCTPTokenAlreadyAdded();
        // Check that symbol hasn't been added yet and starts with "CCTP."
        _assertCanAddSymbol(symbol);
        // Add token <> symbol link
        tokenToSymbol[token] = symbol;
        symbolToToken[symbol] = token;
        // Set token fee
        _setTokenFee(token, relayerFee, minBaseFee, minSwapFee, maxFee);
    }

    /// @notice Updates the fee structure for a supported Circle token.
    /// @dev Will revert if the token is not supported.
    /// @param token        Address of the token
    /// @param relayerFee   Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @param minBaseFee   Minimum fee for bridging a token to this chain using a base request
    /// @param minSwapFee   Minimum fee for bridging a token to this chain using a swap request
    /// @param maxFee       Maximum fee for bridging a token to this chain
    function setTokenFee(
        address token,
        uint256 relayerFee,
        uint256 minBaseFee,
        uint256 minSwapFee,
        uint256 maxFee
    ) external onlyOwner {
        if (!_bridgeTokens.contains(token)) revert CCTPTokenNotFound();
        _setTokenFee(token, relayerFee, minBaseFee, minSwapFee, maxFee);
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Sets the fee structure for a supported Circle token.
    function _setTokenFee(
        address token,
        uint256 relayerFee,
        uint256 minBaseFee,
        uint256 minSwapFee,
        uint256 maxFee
    ) internal {
        _tokenFees[token] = CCTPFee({
            relayerFee: relayerFee.safeCastToUint40(),
            minBaseFee: minBaseFee.safeCastToUint72(),
            minSwapFee: minSwapFee.safeCastToUint72(),
            maxFee: maxFee.safeCastToUint72()
        });
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Checks that the symbol hasn't been added yet and starts with "CCTP."
    function _assertCanAddSymbol(string memory symbol) internal view {
        // Check if the symbol has already been added
        if (symbolToToken[symbol] != address(0)) revert CCTPSymbolAlreadyAdded();
        // Cast to bytes to check the length
        bytes memory symbolBytes = bytes(symbol);
        // Check that symbol is correct: starts with "CCTP." and has at least 1 more character
        if (symbolBytes.length <= SYMBOL_PREFIX_LENGTH) revert CCTPSymbolIncorrect();
        for (uint256 i = 0; i < SYMBOL_PREFIX_LENGTH; ) {
            if (symbolBytes[i] != SYMBOL_PREFIX[i]) revert CCTPSymbolIncorrect();
            unchecked {
                ++i;
            }
        }
    }
}
