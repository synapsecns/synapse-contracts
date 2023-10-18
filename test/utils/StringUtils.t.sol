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

    function concat(string memory a, string memory b) public pure returns (string memory) {
        return StringUtils.concat(a, b);
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

    function testConcat() public {
        string memory a = "Hello, ";
        string memory b = "World!";
        string memory expected = "Hello, World!";
        string memory actual = harness.concat(a, b);
        assertEq(actual, expected);
    }
}
