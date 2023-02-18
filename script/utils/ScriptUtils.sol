// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

abstract contract ScriptUtils {
    bytes1 internal constant NEWLINE = bytes1("\n");
    bytes1 internal constant ZERO = bytes1("0");
    bytes1 internal constant NINE = bytes1("9");

    /// @dev Wrapper for block.chainid, which is not directly accessible in 0.6.12
    function _chainId() internal view returns (uint256 chainId) {
        // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        this;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }

    /// @dev Shortcut for concatenation of two strings.
    function _concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /// @dev Shortcut for concatenation of three strings.
    function _concat(
        string memory a,
        string memory b,
        string memory c
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    /// @dev Shortcut for concatenation of four strings.
    function _concat(
        string memory a,
        string memory b,
        string memory c,
        string memory d
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }

    /// @dev Shortcut for concatenation of five strings.
    function _concat(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }

    /// @dev Splits string having newlines as the separators.
    function _splitString(bytes memory bStr) internal pure returns (bytes[] memory res) {
        if (bStr.length == 0) return res;
        uint256 found = 1;
        for (uint256 i = 0; i < bStr.length; ++i) {
            if (bStr[i] == NEWLINE) {
                ++found;
            }
        }
        res = new bytes[](found);
        found = 0;
        uint256 start = 0;
        while (start < bStr.length) {
            uint256 end = start;
            while (end < bStr.length && bStr[end] != NEWLINE) ++end;
            // [start, end)
            res[found] = new bytes(end - start);
            for (uint256 i = start; i < end; ++i) {
                res[found][i - start] = bStr[i];
            }
            ++found;
            start = end + 1;
        }
    }

    /// @dev Derives integer from its string representation.
    function _strToInt(string memory str) internal pure returns (uint256 val) {
        bytes memory bStr = bytes(str);
        for (uint256 i = 0; i < bStr.length; ++i) {
            bytes1 b = bStr[i];
            require(b >= ZERO && b <= NINE, "Not a digit");
            val = val * 10 + uint8(b) - uint8(ZERO);
        }
    }
}
