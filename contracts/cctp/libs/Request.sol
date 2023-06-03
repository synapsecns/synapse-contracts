// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IncorrectRequestLength, UnknownRequestVersion} from "./Errors.sol";
import {BytesArray, SlicerLib} from "./Slicer.sol";

type Request is uint256;

using RequestLib for Request global;

/// # Memory layout of common Request fields for versions [REQUEST_BASE, ...)
/// > - (originDomain, nonce, originBurnToken) are optimized for storage in a single slot.
///
/// | Position   | Field           | Type    | Bytes | Description                                        |
/// | ---------- | --------------- | ------- | ----- | -------------------------------------------------- |
/// | [000..004) | originDomain    | uint32  | 4     | Domain of the origin chain                         |
/// | [004..012) | nonce           | uint64  | 8     | Nonce of the CCTP message on origin domain         |
/// | [012..032) | originBurnToken | address | 20    | Circle token that was burned on origin domain      |
/// | [032..064) | amount          | uint256 | 32    | Amount of tokens to burn                           |
/// | [064..084) | recipient       | address | 20    | Recipient of the tokens on destination domain      |
///
/// # Memory layout of common Request fields for versions [REQUEST_SWAP, ...)
/// > - (pool, tokenIndexFrom, tokenIndexTo, deadline) are optimized for storage in a single slot.
/// > - deadline is stored as uint80, which is enough to store timestamps until year 3*10^16.
/// > - If a swap fails due to deadline or minAmountOut check, the recipient will receive the minted Circle token.
///
/// | Position   | Field           | Type    | Bytes | Description                                        |
/// | ---------- | --------------- | ------- | ----- | -------------------------------------------------- |
/// | [084..104) | pool            | address | 20    | Liquidity pool for swapping Circle token           |
/// | [104..105) | tokenIndexFrom  | uint8   | 1     | Index of the minted Circle token in the pool       |
/// | [105..106) | tokenIndexTo    | uint8   | 1     | Index of the final token in the pool               |
/// | [106..116) | deadline        | uint80  | 10    | Latest timestamp to execute the swap               |
/// | [116..148) | minAmountOut    | uint256 | 32    | Minimum amount of tokens to receive from the swap  |
library RequestLib {
    uint32 internal constant REQUEST_BASE = 0;
    uint32 internal constant REQUEST_SWAP = 1;

    uint256 private constant OFFSET_ORIGIN_DATA = 0;
    uint256 private constant OFFSET_AMOUNT = OFFSET_ORIGIN_DATA + 32;
    uint256 private constant OFFSET_RECIPIENT = OFFSET_AMOUNT + 32;
    uint256 private constant REQUEST_BASE_LENGTH = OFFSET_RECIPIENT + 20;

    uint256 private constant OFFSET_SWAP_PARAMS = REQUEST_BASE_LENGTH;
    uint256 private constant OFFSET_MIN_AMOUNT_OUT = OFFSET_SWAP_PARAMS + 32;
    uint256 private constant REQUEST_SWAP_LENGTH = OFFSET_MIN_AMOUNT_OUT + 32;
    uint256 private constant SWAP_PARAMS_LENGTH = REQUEST_SWAP_LENGTH - REQUEST_BASE_LENGTH;

    /// @notice Formats the base request into a bytes array.
    /// @param originDomain_        Domain of the origin chain
    /// @param nonce_               Nonce of the CCTP message on origin domain
    /// @param originBurnToken_     Circle token that was burned on origin domain
    /// @param amount_              Amount of tokens to burn
    /// @param recipient_           Recipient of the tokens on destination domain
    /// @return formattedRequest    Properly formatted base request
    function formatBaseRequest(
        uint32 originDomain_,
        uint64 nonce_,
        address originBurnToken_,
        uint256 amount_,
        address recipient_
    ) internal pure returns (bytes memory formattedRequest) {
        formattedRequest = abi.encodePacked(originDomain_, nonce_, originBurnToken_, amount_, recipient_);
    }

    /// @notice Formats the swap parameters part of the swap request into a bytes array.
    /// @param pool_                Liquidity pool for swapping Circle token
    /// @param tokenIndexFrom_      Index of the minted Circle token in the pool
    /// @param tokenIndexTo_        Index of the final token in the pool
    /// @param deadline_            Latest timestamp to execute the swap
    /// @param minAmountOut_        Minimum amount of tokens to receive from the swap
    /// @return formattedSwapParams Properly formatted swap parameters
    function formatSwapParams(
        address pool_,
        uint8 tokenIndexFrom_,
        uint8 tokenIndexTo_,
        uint80 deadline_,
        uint256 minAmountOut_
    ) internal pure returns (bytes memory formattedSwapParams) {
        formattedSwapParams = abi.encodePacked(pool_, tokenIndexFrom_, tokenIndexTo_, deadline_, minAmountOut_);
    }

    /// @notice Formats the request into a bytes array.
    /// @dev Will revert if the either of these is true:
    /// - Request version is unknown.
    /// - Base request is not properly formatted.
    /// - Swap parameters are specified for a base request.
    /// - Swap parameters are not properly formatted.
    /// @param requestVersion       Version of the request format
    /// @param baseRequest_         Formatted base request
    /// @param swapParams_          Formatted swap parameters
    /// @return formattedRequest    Properly formatted swap request
    function formatRequest(
        uint32 requestVersion,
        bytes memory baseRequest_,
        bytes memory swapParams_
    ) internal pure returns (bytes memory formattedRequest) {
        if (requestVersion > REQUEST_SWAP) revert UnknownRequestVersion();
        if (baseRequest_.length != REQUEST_BASE_LENGTH) revert IncorrectRequestLength();
        if (requestVersion == REQUEST_BASE && swapParams_.length != 0) revert IncorrectRequestLength();
        if (requestVersion == REQUEST_SWAP && swapParams_.length != SWAP_PARAMS_LENGTH) revert IncorrectRequestLength();
        formattedRequest = abi.encodePacked(baseRequest_, swapParams_);
    }

    /// @notice Wraps the memory representation of a Request into a Request type.
    function wrapRequest(uint32 requestVersion, bytes memory request) internal pure returns (Request) {
        if (requestVersion > REQUEST_SWAP) revert UnknownRequestVersion();
        if (requestVersion == REQUEST_BASE && request.length != REQUEST_BASE_LENGTH) {
            revert IncorrectRequestLength();
        }
        if (requestVersion == REQUEST_SWAP && request.length != REQUEST_SWAP_LENGTH) {
            revert IncorrectRequestLength();
        }
        // Wrap the BytesArray into Request type
        return Request.wrap(BytesArray.unwrap(SlicerLib.wrapBytesArray(request)));
    }

    /// @notice Convenience shortcut for unwrapping a Request into a BytesArray.
    function unwrap(Request request) internal pure returns (BytesArray) {
        return BytesArray.wrap(Request.unwrap(request));
    }

    // ═══════════════════════════════════════════ REQUEST SLICING: BASE ═══════════════════════════════════════════════

    /// @notice Extracts the data related to the origin domain.
    /// @param request          Request to slice
    /// @return originDomain    Domain of the origin chain
    /// @return nonce           Nonce of the CCTP message on origin domain
    /// @return originBurnToken Circle token that was burned on origin domain
    function originData(Request request)
        internal
        pure
        returns (
            uint32 originDomain,
            uint64 nonce,
            address originBurnToken,
            uint256 amount
        )
    {
        bytes32 data = request.unwrap().sliceBytes32(OFFSET_ORIGIN_DATA);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // To get originDomain, we need to shift the data by 256-32=224 bits
            originDomain := shr(224, data)
            // To get nonce, we need to shift the data by 256-96=160 bits, then mask the result with 0xFFFFFFFFFFFFFFFF
            nonce := and(shr(160, data), 0xFFFFFFFFFFFFFFFF)
            // To get originBurnToken, we need to mask the data with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            originBurnToken := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
        // Read as bytes32 and then cast to uint256
        amount = uint256(request.unwrap().sliceBytes32(OFFSET_AMOUNT));
    }

    /// @notice Extracts the recipient of the tokens on destination domain.
    /// @param request      Request to slice
    /// @return Recipient of the tokens on destination domain
    function recipient(Request request) internal pure returns (address) {
        return request.unwrap().sliceAddress(OFFSET_RECIPIENT);
    }

    // ═══════════════════════════════════════════ REQUEST SLICING: SWAP ═══════════════════════════════════════════════

    /// @notice Extracts the swap parameters of the request
    /// @param request          Request to slice
    /// @return pool            Liquidity pool for swapping Circle token
    /// @return tokenIndexFrom  Index of the minted Circle token in the pool
    /// @return tokenIndexTo    Index of the final token in the pool
    /// @return deadline        Latest timestamp to execute the swap
    /// @return minAmountOut    Minimum amount of tokens to receive from the swap
    function swapParams(Request request)
        internal
        pure
        returns (
            address pool,
            uint8 tokenIndexFrom,
            uint8 tokenIndexTo,
            uint80 deadline,
            uint256 minAmountOut
        )
    {
        bytes32 data = request.unwrap().sliceBytes32(OFFSET_SWAP_PARAMS);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // To get pool, we need to shift the data by 256-160=96 bits
            pool := shr(96, data)
            // To get tokenIndexFrom, we need to shift the data by 256-168=88 bits, then mask the result with 0xFF
            tokenIndexFrom := and(shr(88, data), 0xFF)
            // To get tokenIndexTo, we need to shift the data by 256-176=80 bits, then mask the result with 0xFF
            tokenIndexTo := and(shr(80, data), 0xFF)
            // To get deadline, we need to mask the data with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            deadline := and(data, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
        // Read as bytes32 and then cast to uint256
        minAmountOut = uint256(request.unwrap().sliceBytes32(OFFSET_MIN_AMOUNT_OUT));
    }
}
