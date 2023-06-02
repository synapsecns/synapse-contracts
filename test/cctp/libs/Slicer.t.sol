// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexOutOrRange, SliceOverrun} from "../../../contracts/cctp/libs/Errors.sol";
import {SlicerLibHarness} from "../harnesses/SlicerLibHarness.sol";
import {Test} from "forge-std/Test.sol";

contract SlicerLibraryTest is Test {
    SlicerLibHarness public libHarness;
    bytes public testBytes;

    function setUp() public {
        libHarness = new SlicerLibHarness();
        for (uint256 i = 0; i <= type(uint8).max; ++i) {
            testBytes.push(bytes1(uint8(i)));
        }
    }

    function testSliceBytes32() public {
        uint256 maxIndex = testBytes.length - 32;
        for (uint256 i = 0; i <= maxIndex; ++i) {
            assertEq(libHarness.sliceBytes32(testBytes, i), dumbSliceBytes32(i));
        }
    }

    function testSliceAddress() public {
        uint256 maxIndex = testBytes.length - 20;
        for (uint256 i = 0; i <= maxIndex; ++i) {
            assertEq(libHarness.sliceAddress(testBytes, i), dumbSliceAddress(i));
        }
    }

    function testSliceBytes32IndexOutOfRange(uint256 index) public {
        index = bound(index, testBytes.length, type(uint256).max);
        vm.expectRevert(IndexOutOrRange.selector);
        libHarness.sliceBytes32(testBytes, index);
    }

    function testSliceBytes32SliceOverrun() public {
        uint256 maxIndex = testBytes.length - 32;
        for (uint256 i = maxIndex + 1; i < testBytes.length; ++i) {
            vm.expectRevert(SliceOverrun.selector);
            libHarness.sliceBytes32(testBytes, i);
        }
    }

    function testSliceBytes32SliceOverrunShortArray() public {
        bytes memory arr = new bytes(16);
        for (uint256 i = 0; i < arr.length; ++i) {
            vm.expectRevert(SliceOverrun.selector);
            libHarness.sliceBytes32(arr, i);
        }
    }

    function testSliceAddressIndexOutOfRange(uint256 index) public {
        index = bound(index, testBytes.length, type(uint256).max);
        vm.expectRevert(IndexOutOrRange.selector);
        libHarness.sliceAddress(testBytes, index);
    }

    function testSliceAddressSliceOverrun() public {
        uint256 maxIndex = testBytes.length - 20;
        for (uint256 i = maxIndex + 1; i < testBytes.length; ++i) {
            vm.expectRevert(SliceOverrun.selector);
            libHarness.sliceAddress(testBytes, i);
        }
    }

    function testSliceAddressSliceOverrunShortArray() public {
        bytes memory arr = new bytes(16);
        for (uint256 i = 0; i < arr.length; ++i) {
            vm.expectRevert(SliceOverrun.selector);
            libHarness.sliceAddress(arr, i);
        }
    }

    function dumbSliceAddress(uint256 index) public view returns (address) {
        bytes memory arr = new bytes(32);
        for (uint256 i = 0; i < 20; ++i) {
            arr[12 + i] = testBytes[index + i];
        }
        return abi.decode(arr, (address));
    }

    function dumbSliceBytes32(uint256 index) public view returns (bytes32) {
        bytes memory arr = new bytes(32);
        for (uint256 i = 0; i < 32; ++i) {
            arr[i] = testBytes[index + i];
        }
        return abi.decode(arr, (bytes32));
    }
}
