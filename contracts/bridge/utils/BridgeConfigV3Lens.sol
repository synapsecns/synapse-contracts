// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @notice Contract to introspect BridgeConfigV3, which is deployed on Mainnet.
 * A test or a script contract could inherit from BridgeConfigV3Lens in order to
 * batch fetch information about the bridge tokens.
 */
contract BridgeConfigV3Lens {
    bytes1 private constant ZERO = bytes1("0");
    bytes1 private constant NINE = bytes1("9");
    bytes1 private constant A_LOWER = bytes1("a");
    bytes1 private constant A_UPPER = bytes1("A");
    bytes1 private constant F_LOWER = bytes1("f");
    bytes1 private constant F_UPPER = bytes1("F");

    /// @notice Returns address value for a string containing 0x prefixed address.
    function stringToAddress(string memory str) public pure returns (address addr) {
        bytes memory bStr = bytes(str);
        uint256 length = bStr.length;
        require(length == 42, "Not a 0x address");
        uint256 val = 0;
        for (uint256 i = 0; i < 40; ++i) {
            // Shift left 4 bits and apply 4 bits derived from the string character
            val <<= 4;
            val = val | _charToInt(bStr[2 + i]);
        }
        addr = address(uint160(val));
    }

    /// @dev Returns integer value denoted by a character (1 for "1", 15 for "F" or "f").
    function _charToInt(bytes1 b) internal pure returns (uint8 val) {
        if (b >= ZERO && b <= NINE) {
            // This never underflows
            val = uint8(b) - uint8(ZERO);
        } else if (b >= A_LOWER && b <= F_LOWER) {
            // This never underflows; A = 10
            val = uint8(b) - uint8(A_LOWER) + 10;
        } else if (b >= A_UPPER && b <= F_UPPER) {
            // This never underflows; A = 10
            val = uint8(b) - uint8(A_UPPER) + 10;
        }
    }
}
