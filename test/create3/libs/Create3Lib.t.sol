// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Create3LibHarness} from "../harnesses/Create3LibHarness.sol";
import {SimpleContract, SimpleArgContract} from "../mocks/SimpleContracts.sol";

import {Test} from "forge-std/Test.sol";

contract Create3LibraryTest is Test {
    Create3LibHarness public create3LibHarness;

    address public simpleReference;
    address public simpleArgReference;

    function setUp() public {
        create3LibHarness = new Create3LibHarness();
        simpleReference = address(new SimpleContract());
        simpleArgReference = address(new SimpleArgContract(42));
    }

    function testCreate3NoArgs(bytes32 salt) public {
        address predictedAddress = create3LibHarness.predictAddress(salt);
        address deployedAddress = create3LibHarness.create3(salt, type(SimpleContract).creationCode, 0);
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, simpleReference.code);
    }

    function testCreate3WithEther(
        bytes32 salt,
        uint256 totalValue,
        uint256 forwardedValue
    ) public {
        deal(address(this), totalValue);
        forwardedValue = bound(forwardedValue, 0, totalValue);
        address predictedAddress = create3LibHarness.predictAddress(salt);
        // Use different ether values for constructor and msg.value for testing
        address deployedAddress = create3LibHarness.create3{value: totalValue}(
            salt,
            type(SimpleContract).creationCode,
            forwardedValue
        );
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, simpleReference.code);
        assertEq(address(deployedAddress).balance, forwardedValue);
    }

    function testCreate3WithArgs(bytes32 salt, uint256 arg) public {
        address predictedAddress = create3LibHarness.predictAddress(salt);
        bytes memory creationCode = abi.encodePacked(type(SimpleArgContract).creationCode, abi.encode(arg));
        address deployedAddress = create3LibHarness.create3(salt, creationCode, 0);
        assertEq(predictedAddress, deployedAddress);
        assertEq(deployedAddress.code, simpleArgReference.code);
        assertEq(SimpleArgContract(deployedAddress).arg(), arg);
    }
}
