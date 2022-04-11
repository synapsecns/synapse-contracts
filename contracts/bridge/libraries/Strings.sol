// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

/**
 * @dev Library for manipulating strings in solidity
*/
library Strings {
    /**
    * @dev Concatenates a + b
     */
    function append(string memory a, string memory b)
    internal
    pure
    returns (string memory)
    {
        return string(abi.encodePacked(a, b));
    }


    /**
     * @dev Concatenates a + b + c
     */
    function append(string memory a, string memory b, string memory c)
    internal
    pure
    returns (string memory)
    {
        return string(abi.encodePacked(a, b, c));
    }

    /**
    * @dev Concatenates a + b + c + d
     */
    function append(string memory a, string memory b, string memory c, string memory d)
    internal
    pure
    returns (string memory)
    {
        return string(abi.encodePacked(a, b, c,d));
    }

    /**
     * @dev Converts a bytes16 to a string
     * for a full explanation, see: https://stackoverflow.com/a/69266989
     */
    function toHex16 (bytes16 data) internal pure returns (bytes32 result) {
        result = bytes32 (data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000 |
        (bytes32 (data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64;
        result = result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000 |
        (result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32;
        result = result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000 |
        (result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16;
        result = result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000 |
        (result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8;
        result = (result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4 |
        (result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8;
        result = bytes32 (0x3030303030303030303030303030303030303030303030303030303030303030 +
        uint256 (result) +
            (uint256 (result) + 0x0606060606060606060606060606060606060606060606060606060606060606 >> 4 &
            // 39 can be changed to 7 for lowercase output
            0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 39);
    }

    /**
     * @dev Converts a bytes32 to a string
     * for a full explanation, see: https://stackoverflow.com/a/69266989
     */
    function toHex(bytes32 data) internal pure returns (string memory) {
        return string (abi.encodePacked ("0x", toHex16 (bytes16 (data)), toHex16 (bytes16 (data << 128))));
    }
}
