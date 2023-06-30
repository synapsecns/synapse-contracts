// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CastOverflow} from "../../../contracts/cctp/libs/Errors.sol";
import {TypeCastLibHarness} from "../harnesses/TypeCastsLibHarness.sol";

import {Test} from "forge-std/Test.sol";

contract TypeCastsLibraryTest is Test {
    TypeCastLibHarness public libHarness;

    function setUp() public {
        libHarness = new TypeCastLibHarness();
    }

    function testAddressToBytes32(address addr) public {
        bytes32 result = libHarness.addressToBytes32(addr);
        assertEq(result, abi.decode(abi.encode(addr), (bytes32)));
    }

    function testBytes32ToAddress(bytes32 buf) public {
        address result = libHarness.bytes32ToAddress(buf);
        // Discard highest 96 bits
        assertEq(result, address(bytes20(buf << 96)));
    }

    function testAddressToBytes32Roundtrip(address addr) public {
        bytes32 buf = libHarness.addressToBytes32(addr);
        address result = libHarness.bytes32ToAddress(buf);
        assertEq(result, addr);
    }

    function testSafeCastToUint40(uint40 value) public {
        uint40 result = libHarness.safeCastToUint40(value);
        assertEq(result, value);
    }

    function testSafeCastToUint40RevertsOnOverflow(uint256 value) public {
        value = bound(value, uint256(type(uint40).max) + 1, type(uint256).max);
        vm.expectRevert(CastOverflow.selector);
        libHarness.safeCastToUint40(value);
    }

    function testSafeCastToUint72(uint72 value) public {
        uint72 result = libHarness.safeCastToUint72(value);
        assertEq(result, value);
    }

    function testSafeCastToUint72RevertsOnOverflow(uint256 value) public {
        value = bound(value, uint256(type(uint72).max) + 1, type(uint256).max);
        vm.expectRevert(CastOverflow.selector);
        libHarness.safeCastToUint72(value);
    }
}
