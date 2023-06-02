// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexOutOrRange, SliceOverrun} from "./Errors.sol";

/// `BytesArray` is a custom type for storing a memory reference to a bytes array.
type BytesArray is uint256;

using SlicerLib for BytesArray global;

/// Library for slicing bytes arrays.
/// # BytesArray stack layout (from highest bits to lowest)
///
/// | Position   | Field | Type    | Bytes | Description                              |
/// | ---------- | ----- | ------- | ----- | ---------------------------------------- |
/// | (032..016] | loc   | uint128 | 16    | Memory address of underlying bytes array |
/// | (016..000] | len   | uint128 | 16    | Length of underlying bytes array         |
library SlicerLib {
    /// @notice Wrap a bytes array into a `BytesArray` custom type.
    function wrapBytesArray(bytes memory arr) internal pure returns (BytesArray) {
        // `bytes arr` is stored in memory in the following way
        // 1. First, uint256 arr.length is stored. That requires 32 bytes (0x20).
        // 2. Then, the array data is stored.
        uint256 loc;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // We add 0x20 to get the locations where the array data starts
            loc := add(arr, 0x20)
        }
        uint256 len = arr.length;
        // There is no scenario where loc or len would overflow uint128, so we omit this check.
        // We use the highest 128 bits to encode the location and the lowest 128 bits to encode the length.
        return BytesArray.wrap((loc << 128) | len);
    }

    /// @notice Slices 32 bytes from the underlying bytes array starting from the given index.
    function sliceBytes32(BytesArray arr, uint256 index) internal pure returns (bytes32 slice) {
        (uint256 loc, uint256 len) = _unwrap(arr);
        unchecked {
            if (index >= len) revert IndexOutOrRange();
            // len fits into uint128, so index+32 never overflows
            if (index + 32 > len) revert SliceOverrun();
        }
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // We need to load 32 bytes starting from loc + index
            slice := mload(add(loc, index))
        }
    }

    /// @notice Slices 20 bytes from the underlying bytes array starting from the given index,
    /// and returns it as an address.
    function sliceAddress(BytesArray arr, uint256 index) internal pure returns (address slice) {
        (uint256 loc, uint256 len) = _unwrap(arr);
        unchecked {
            if (index >= len) revert IndexOutOrRange();
            // len fits into uint128, so index+20 never overflows
            if (index + 20 > len) revert SliceOverrun();
        }
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // To slice the address we need to do two steps:
            // 1. Load 32 bytes starting from loc + index: this gets the address in the highest 20 bytes
            // 2. Shift the result to the right by 12 bytes (96 bits): this clears the dirty lowest 12 bytes
            slice := shr(96, mload(add(loc, index)))
        }
    }

    // ══════════════════════════════════════════════ PRIVATE HELPERS ══════════════════════════════════════════════════

    function _unwrap(BytesArray arr) private pure returns (uint256 loc, uint256 len) {
        // loc is stored in the highest 16 bytes of the underlying uint256
        loc = BytesArray.unwrap(arr) >> 128;
        // len is stored in the lowest 16 bytes of the underlying uint256
        len = uint128(BytesArray.unwrap(arr));
    }
}
