// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TypeCasts} from "../../../contracts/cctp/libs/TypeCasts.sol";

contract TypeCastLibHarness {
    function addressToBytes32(address addr) public pure returns (bytes32) {
        bytes32 result = TypeCasts.addressToBytes32(addr);
        return result;
    }

    function bytes32ToAddress(bytes32 buf) public pure returns (address) {
        address result = TypeCasts.bytes32ToAddress(buf);
        return result;
    }

    function safeCastToUint40(uint256 value) public pure returns (uint40) {
        uint40 result = TypeCasts.safeCastToUint40(value);
        return result;
    }

    function safeCastToUint72(uint256 value) public pure returns (uint72) {
        uint72 result = TypeCasts.safeCastToUint72(value);
        return result;
    }
}
