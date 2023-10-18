// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

library StringUtils {
    bytes1 private constant A_LOWERCASE = bytes1("a");
    bytes1 private constant Z_LOWERCASE = bytes1("z");
    bytes1 private constant A_UPPERCASE = bytes1("A");
    bytes1 private constant Z_UPPERCASE = bytes1("Z");

    uint8 private constant CASE_DIFF = uint8(A_LOWERCASE) - uint8(A_UPPERCASE);

    /// @notice Returns string with all Latin uppercase characters converted to lowercase.
    function toLowerCase(string memory s) internal pure returns (string memory lower) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= A_UPPERCASE && b[i] <= Z_UPPERCASE) {
                b[i] = bytes1(uint8(b[i]) + CASE_DIFF);
            }
        }
        return string(b);
    }

    /// @notice Returns string with all Latin lowercase characters converted to uppercase.
    function toUpperCase(string memory s) internal pure returns (string memory upper) {
        bytes memory b = bytes(s);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= A_LOWERCASE && b[i] <= Z_LOWERCASE) {
                b[i] = bytes1(uint8(b[i]) - CASE_DIFF);
            }
        }
        return string(b);
    }

    /// @notice Returns the concatenation of two strings.
    /// @dev This is used instead of string.concat, which is only available in Solidity >=0.8.
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
