// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TypeCasts} from "../../../contracts/cctp/libs/TypeCasts.sol";

contract TypeCastLibHarness {
    function addressToBytes32(address addr) public pure returns (bytes32) {
        return TypeCasts.addressToBytes32(addr);
    }

    function bytes32ToAddress(bytes32 buf) public pure returns (address) {
        return TypeCasts.bytes32ToAddress(buf);
    }
}
