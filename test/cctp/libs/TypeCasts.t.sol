// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TypeCastLibHarness} from "../harnesses/TypeCastsLibHarness.sol";

import {Test} from "forge-std/Test.sol";

contract TypeCastsLibraryTest is Test {
    function testAddressToBytes32(address addr) public {
        TypeCastLibHarness harness = new TypeCastLibHarness();
        assertEq(harness.bytes32ToAddress(harness.addressToBytes32(addr)), addr);
    }
}
