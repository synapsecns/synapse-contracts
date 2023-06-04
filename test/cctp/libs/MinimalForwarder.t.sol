// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ForwarderDeploymentFailed} from "../../../contracts/cctp/libs/Errors.sol";
import {MinimalForwarderLib, MinimalForwarderLibHarness} from "../harnesses/MinimalForwarderLibHarness.sol";
import {Test} from "forge-std/Test.sol";

contract MinimalForwarderLibraryTest is Test {
    MinimalForwarderLibHarness public libHarness;

    function setUp() public {
        libHarness = new MinimalForwarderLibHarness();
    }

    function testDeploy(bytes32 salt) public {
        address forwarder = libHarness.deploy(salt);
        // Check that the forwarder was deployed at the predicted address
        assertEq(forwarder, libHarness.predictAddress(address(libHarness), salt));
        // Check that the forwarder has the correct code
        assertEq(forwarder.code, MinimalForwarderLib.FORWARDER_BYTECODE);
    }

    function testDeployRevertsUsingSameSalt(bytes32 salt) public {
        libHarness.deploy(salt);
        vm.expectRevert(ForwarderDeploymentFailed.selector);
        libHarness.deploy(salt);
    }

    function testForwarderBytecodeLength() public {
        // We use push32 to push the bytecode onto stack, so need to check that it's the right length
        assertEq(MinimalForwarderLib.FORWARDER_BYTECODE.length, 32);
    }
}
