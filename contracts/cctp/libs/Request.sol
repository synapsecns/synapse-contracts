// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IncorrectRequestLength, UnknownRequestVersion} from "./Errors.sol";

/// # Base Request layout
///
/// | Field           | Type    | Description                                    |
/// | --------------- | ------- | ---------------------------------------------- |
/// | originDomain    | uint32  | Domain of the origin chain used by Circle CCTP |
/// | nonce           | uint64  | Nonce of the CCTP message on origin chain      |
/// | originBurnToken | address | Circle token that was burned on origin chain   |
/// | amount          | uint256 | Amount of tokens burned on origin chain        |
/// | recipient       | address | Recipient of the tokens on destination chain   |
///
/// # Swap Params layout
///
/// | Field          | Type    | Description                                                   |
/// | -------------- | ------- | ------------------------------------------------------------- |
/// | pool           | address | Liquidity pool for swapping Circle token on destination chain |
/// | tokenIndexFrom | uint8   | Index of the minted Circle token in the pool                  |
/// | tokenIndexTo   | uint8   | Index of the final token in the pool                          |
/// | deadline       | uint256 | Latest timestamp to execute the swap                          |
/// | minAmountOut   | uint256 | Minimum amount of tokens to receive from the swap             |
library RequestLib {
    uint32 internal constant REQUEST_BASE = 0;
    uint32 internal constant REQUEST_SWAP = 1;

    /// @notice Length of the encoded base request.
    uint256 internal constant REQUEST_BASE_LENGTH = 5 * 32;
    /// @notice Length of the encoded swap parameters.
    uint256 internal constant SWAP_PARAMS_LENGTH = 5 * 32;
    /// @notice Length of the encoded swap request.
    /// Need 2 extra words for each `bytes` field to store its offset in the full payload, and length.
    uint256 internal constant REQUEST_SWAP_LENGTH = 4 * 32 + REQUEST_BASE_LENGTH + SWAP_PARAMS_LENGTH;

    // ════════════════════════════════════════════════ FORMATTING ═════════════════════════════════════════════════════

    /// @notice Formats the base request into a bytes array.
    /// @param originDomain         Domain of the origin chain
    /// @param nonce                Nonce of the CCTP message on origin chain
    /// @param originBurnToken      Circle token that was burned on origin chain
    /// @param amount               Amount of tokens burned on origin chain
    /// @param recipient            Recipient of the tokens on destination chain
    /// @return formattedRequest    Properly formatted base request
    function formatBaseRequest(
        uint32 originDomain,
        uint64 nonce,
        address originBurnToken,
        uint256 amount,
        address recipient
    ) internal pure returns (bytes memory formattedRequest) {
        return abi.encode(originDomain, nonce, originBurnToken, amount, recipient);
    }

    /// @notice Formats the swap parameters part of the swap request into a bytes array.
    /// @param pool                 Liquidity pool for swapping Circle token on destination chain
    /// @param tokenIndexFrom       Index of the minted Circle token in the pool
    /// @param tokenIndexTo         Index of the final token in the pool
    /// @param deadline             Latest timestamp to execute the swap
    /// @param minAmountOut         Minimum amount of tokens to receive from the swap
    /// @return formattedSwapParams Properly formatted swap parameters
    function formatSwapParams(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 deadline,
        uint256 minAmountOut
    ) internal pure returns (bytes memory formattedSwapParams) {
        return abi.encode(pool, tokenIndexFrom, tokenIndexTo, deadline, minAmountOut);
    }

    /// @notice Formats the request into a bytes array.
    /// @dev Will revert if the either of these is true:
    /// - Request version is unknown.
    /// - Base request is not properly formatted.
    /// - Swap parameters are specified for a base request.
    /// - Swap parameters are not properly formatted.
    /// @param requestVersion       Version of the request format
    /// @param baseRequest          Formatted base request
    /// @param swapParams           Formatted swap parameters
    /// @return formattedRequest    Properly formatted request
    function formatRequest(
        uint32 requestVersion,
        bytes memory baseRequest,
        bytes memory swapParams
    ) internal pure returns (bytes memory formattedRequest) {
        if (baseRequest.length != REQUEST_BASE_LENGTH) revert IncorrectRequestLength();
        if (requestVersion == REQUEST_BASE) {
            if (swapParams.length != 0) revert IncorrectRequestLength();
            // swapParams is empty, so we can just return the base request
            return baseRequest;
        } else if (requestVersion == REQUEST_SWAP) {
            if (swapParams.length != SWAP_PARAMS_LENGTH) revert IncorrectRequestLength();
            // Encode both the base request and the swap parameters
            return abi.encode(baseRequest, swapParams);
        } else {
            revert UnknownRequestVersion();
        }
    }

    // ═════════════════════════════════════════════════ DECODING ══════════════════════════════════════════════════════

    /// @notice Decodes the base request from a bytes array.
    /// @dev Will revert if the request is not properly formatted.
    /// @param baseRequest          Formatted base request
    /// @return originDomain        Domain of the origin chain
    /// @return nonce               Nonce of the CCTP message on origin domain
    /// @return originBurnToken     Circle token that was burned on origin domain
    /// @return amount              Amount of tokens to burn
    /// @return recipient           Recipient of the tokens on destination domain
    function decodeBaseRequest(bytes memory baseRequest)
        internal
        pure
        returns (
            uint32 originDomain,
            uint64 nonce,
            address originBurnToken,
            uint256 amount,
            address recipient
        )
    {
        if (baseRequest.length != REQUEST_BASE_LENGTH) revert IncorrectRequestLength();
        return abi.decode(baseRequest, (uint32, uint64, address, uint256, address));
    }

    /// @notice Decodes the swap parameters from a bytes array.
    /// @dev Will revert if the swap parameters are not properly formatted.
    /// @param swapParams           Formatted swap parameters
    /// @return pool                Liquidity pool for swapping Circle token on destination chain
    /// @return tokenIndexFrom      Index of the minted Circle token in the pool
    /// @return tokenIndexTo        Index of the final token in the pool
    /// @return deadline            Latest timestamp to execute the swap
    /// @return minAmountOut        Minimum amount of tokens to receive from the swap
    function decodeSwapParams(bytes memory swapParams)
        internal
        pure
        returns (
            address pool,
            uint8 tokenIndexFrom,
            uint8 tokenIndexTo,
            uint256 deadline,
            uint256 minAmountOut
        )
    {
        if (swapParams.length != SWAP_PARAMS_LENGTH) revert IncorrectRequestLength();
        return abi.decode(swapParams, (address, uint8, uint8, uint256, uint256));
    }

    /// @notice Decodes the versioned request from a bytes array.
    /// @dev Will revert if the either of these is true:
    /// - Request version is unknown.
    /// - Request is not properly formatted.
    /// @param requestVersion       Version of the request format
    /// @param formattedRequest     Formatted request
    /// @return baseRequest         Formatted base request
    /// @return swapParams          Formatted swap parameters
    function decodeRequest(uint32 requestVersion, bytes memory formattedRequest)
        internal
        pure
        returns (bytes memory baseRequest, bytes memory swapParams)
    {
        if (requestVersion == REQUEST_BASE) {
            if (formattedRequest.length != REQUEST_BASE_LENGTH) revert IncorrectRequestLength();
            return (formattedRequest, "");
        } else if (requestVersion == REQUEST_SWAP) {
            if (formattedRequest.length != REQUEST_SWAP_LENGTH) revert IncorrectRequestLength();
            return abi.decode(formattedRequest, (bytes, bytes));
        } else {
            revert UnknownRequestVersion();
        }
    }
}
