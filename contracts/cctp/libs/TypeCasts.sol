// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CastOverflow} from "./Errors.sol";

library TypeCasts {
    // alignment preserving cast
    function addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    // alignment preserving cast
    function bytes32ToAddress(bytes32 buf) internal pure returns (address) {
        return address(uint160(uint256(buf)));
    }

    /// @dev Casts uint256 to uint40, reverts on overflow
    function safeCastToUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert CastOverflow();
        }
        return uint40(value);
    }

    /// @dev Casts uint256 to uint72, reverts on overflow
    function safeCastToUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert CastOverflow();
        }
        return uint72(value);
    }
}
