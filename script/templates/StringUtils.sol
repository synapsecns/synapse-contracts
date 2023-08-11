// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

// solhint-disable reason-string
library StringUtils {
    /// @dev The value returned by indexOf when the substring is not found.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    bytes1 private constant ZERO = bytes1("0");
    bytes1 private constant NINE = bytes1("9");

    // ══════════════════════════════════════════════════ SLICING ══════════════════════════════════════════════════════

    /// @notice Returns a substring of a string in the range [startIndex, endIndex)
    /// @param str          The string to take a substring of
    /// @param startIndex   The start index (inclusive)
    /// @param endIndex     The end index (exclusive)
    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) internal pure returns (string memory) {
        require(startIndex <= endIndex, "StringUtils: invalid substring range");
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    /// @notice Returns a suffix of a string starting at the given index, inclusive: [startIndex, str.length)
    /// @param str          The string to take a suffix of
    /// @param startIndex   The start index (inclusive)
    function suffix(string memory str, uint256 startIndex) internal pure returns (string memory) {
        return substring(str, startIndex, bytes(str).length);
    }

    /// @notice Returns a prefix of a string ending at the given index, exclusive: [0, endIndex)
    /// @param str          The string to take a prefix of
    /// @param endIndex     The end index (exclusive)
    function prefix(string memory str, uint256 endIndex) internal pure returns (string memory) {
        return substring(str, 0, endIndex);
    }

    // ═══════════════════════════════════════════════ CONCATENATION ═══════════════════════════════════════════════════

    // Note: this is implemented, as `string.concat` is not available until Solidity 0.8.0.

    /// @notice Concatenates two strings
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /// @notice Concatenates three strings
    function concat(
        string memory a,
        string memory b,
        string memory c
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    /// @notice Concatenates four strings
    function concat(
        string memory a,
        string memory b,
        string memory c,
        string memory d
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }

    /// @notice Concatenates five strings
    function concat(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }

    /// @notice Concatenates six strings
    function concat(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f));
    }

    /// @notice Duplicates a string a given number of times.
    /// Example: duplicate("abc", 3) = "abcabcabc"
    function duplicate(string memory str, uint256 times) internal pure returns (string memory duplicateStr) {
        duplicateStr = "";
        for (uint256 i = 0; i < times; i++) {
            duplicateStr = concat(duplicateStr, str);
        }
    }

    // ════════════════════════════════════════════════ COMPARISON ═════════════════════════════════════════════════════

    /// @notice Checks if two strings are equal
    /// @param a    The first string
    /// @param b    The second string
    function equals(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @notice Returns the index of the first occurrence of a substring in a string, or NOT_FOUND if not found.
    /// @param str       The string to search in
    /// @param subStr    The substring to search for
    function indexOf(string memory str, string memory subStr) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        bytes memory subStrBytes = bytes(subStr);
        if (subStrBytes.length > strBytes.length) {
            return NOT_FOUND;
        }
        for (uint256 startIndex = 0; startIndex <= strBytes.length - subStrBytes.length; ++startIndex) {
            // Check if substring starting from startIndex is equal to subStr
            uint256 endIndex = startIndex + subStrBytes.length;
            if (equals(subStr, substring(str, startIndex, endIndex))) {
                return startIndex;
            }
        }
        return NOT_FOUND;
    }

    /// @notice Returns the index of the last occurrence of a substring in a string, or NOT_FOUND if not found.
    /// @param str       The string to search in
    /// @param subStr    The substring to search for
    function lastIndexOf(string memory str, string memory subStr) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        bytes memory subStrBytes = bytes(subStr);
        if (subStrBytes.length > strBytes.length) {
            return NOT_FOUND;
        }
        for (uint256 endIndex = strBytes.length; endIndex >= subStrBytes.length; --endIndex) {
            // Check if substring ending at endIndex is equal to subStr
            uint256 startIndex = endIndex - subStrBytes.length;
            if (equals(subStr, substring(str, startIndex, endIndex))) {
                return startIndex;
            }
        }
        return NOT_FOUND;
    }

    // ════════════════════════════════════════════ INTEGER CONVERSION ═════════════════════════════════════════════════

    /// @notice Derives integer from its string representation.
    /// @param str  The string to convert
    function toUint(string memory str) internal pure returns (uint256 val) {
        bytes memory bStr = bytes(str);
        for (uint256 i = 0; i < bStr.length; ++i) {
            bytes1 b = bStr[i];
            require(b >= ZERO && b <= NINE, "Not a digit");
            val = val * 10 + uint8(b) - uint8(ZERO);
        }
    }

    /// @notice Converts an integer to its string representation.
    function fromUint(uint256 val) internal pure returns (string memory) {
        // Special case for 0
        if (val == 0) {
            return "0";
        }
        // Calculate length of string
        uint256 length = 0;
        for (uint256 i = val; i > 0; i /= 10) {
            ++length;
        }
        // Populate string in reverse
        bytes memory bStr = new bytes(length);
        for (uint256 i = 0; i < length; ++i) {
            uint8 digit = uint8(val % 10);
            bytes1 char = bytes1(uint8(ZERO) + digit);
            bStr[length - i - 1] = char;
            val = val / 10;
        }
        return string(bStr);
    }

    // ═════════════════════════════════════════════ FLOAT CONVERSION ══════════════════════════════════════════════════

    /// @notice Converts a float to its string representation.
    /// @param val       The float to convert, scaled by 10**decimals
    /// @param decimals  The number of decimals to use
    function fromFloat(uint256 val, uint256 decimals) internal pure returns (string memory) {
        // Get the integer part
        string memory strInt = fromUint(val / 10**decimals);
        // Get the fractional part
        string memory strFrac = fromUint(val % 10**decimals);
        // Pad fractional part with zeros to match the number of decimals
        while (bytes(strFrac).length < decimals) {
            strFrac = concat("0", strFrac);
        }
        // Concatenate integer and fractional parts
        return concat(strInt, ".", strFrac);
    }

    /// @notice Converts a float to its string representation, using 18 decimals.
    /// @param val   The float to convert, scaled by 10**18
    function fromWei(uint256 val) internal pure returns (string memory) {
        return fromFloat(val, 18);
    }
}
