// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ForwarderDeploymentFailed} from "../../../contracts/cctp/libs/Errors.sol";
import {MockCallRecipient} from "../../mocks/MockCallRecipient.sol";
import {MinimalForwarderLib, MinimalForwarderLibHarness} from "../harnesses/MinimalForwarderLibHarness.sol";
import {Test} from "forge-std/Test.sol";

contract MinimalForwarderLibraryTest is Test {
    MinimalForwarderLibHarness public libHarness;
    MockCallRecipient public mockRecipient;

    event CallReceived(address caller, bytes32 data);
    event ValueCallReceived(address caller, bytes32 data, uint256 value);

    function setUp() public {
        libHarness = new MinimalForwarderLibHarness();
        mockRecipient = new MockCallRecipient();
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

    function testForwardCall(bytes32 data) public {
        address forwarder = libHarness.deploy(0);
        bytes memory payload = abi.encodeWithSelector(MockCallRecipient.callMeMaybe.selector, data);
        vm.expectEmit();
        emit CallReceived(forwarder, data);
        bytes memory returnData = libHarness.forwardCall(forwarder, address(mockRecipient), payload);
        assertEq(abi.decode(returnData, (bytes32)), mockRecipient.transformData(data));
    }

    function testForwardCallRevert(bytes32 data) public {
        bytes memory revertMsg = "AHHH IM REVERTIIING";
        address forwarder = libHarness.deploy(0);
        bytes memory payload = abi.encodeWithSelector(MockCallRecipient.callMeMaybe.selector, data);
        // Force mockRecipient.callMeMaybe(data) to revert with revertMsg
        vm.mockCallRevert(address(mockRecipient), payload, revertMsg);
        vm.expectRevert(revertMsg);
        libHarness.forwardCall(forwarder, address(mockRecipient), payload);
    }

    function testForwardCallWithValue(bytes32 data, uint256 value) public {
        vm.deal(address(this), value);
        address forwarder = libHarness.deploy(0);
        bytes memory payload = abi.encodeWithSelector(MockCallRecipient.valueCallMeMaybe.selector, data);
        vm.expectEmit();
        emit ValueCallReceived(forwarder, data, value);
        bytes memory returnData = libHarness.forwardCallWithValue{value: value}(
            forwarder,
            address(mockRecipient),
            payload
        );
        assertEq(abi.decode(returnData, (bytes32)), mockRecipient.transformData(data));
    }

    function testForwardCallWithValueRevert(bytes32 data, uint256 value) public {
        bytes memory revertMsg = "AHHH IM REVERTIIING";
        vm.deal(address(this), value);
        address forwarder = libHarness.deploy(0);
        bytes memory payload = abi.encodeWithSelector(MockCallRecipient.valueCallMeMaybe.selector, data);
        // Force mockRecipient.callMeMaybe(data) to revert with revertMsg
        vm.mockCallRevert(address(mockRecipient), payload, revertMsg);
        vm.expectRevert(revertMsg);
        libHarness.forwardCallWithValue{value: value}(forwarder, address(mockRecipient), payload);
    }
}
