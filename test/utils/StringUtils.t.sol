// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {StringUtils} from "./StringUtils.sol";
import {Test} from "forge-std/Test.sol";

contract StringUtilsHarness {
    function toLowerCase(string memory s) public pure returns (string memory lower) {
        return StringUtils.toLowerCase(s);
    }

    function toUpperCase(string memory s) public pure returns (string memory upper) {
        return StringUtils.toUpperCase(s);
    }
}

contract StringUtilsTest is Test {
    StringUtilsHarness harness;

    function setUp() public {
        harness = new StringUtilsHarness();
    }

    function testToLowerCase() public {
        string memory s = "Hello, World!";
        string memory expected = "hello, world!";
        string memory actual = harness.toLowerCase(s);
        assertEq(actual, expected);
    }

    function testToUpperCase() public {
        string memory s = "Hello, World!";
        string memory expected = "HELLO, WORLD!";
        string memory actual = harness.toUpperCase(s);
        assertEq(actual, expected);
    }
}
