// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IManageable} from "../../contracts/messaging/interfaces/IManageable.sol";
import {MessageBusManager} from "../../contracts/messaging/MessageBusManager.sol";
import {MessageBusReceiver} from "../../contracts/messaging/MessageBusReceiver.sol";

import {MessageBusHarness} from "./MessageBusHarness.sol";
import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract MessageBusManagerTest is Test {
    bytes32 public constant MESSAGE_ID = bytes32("Test");

    MessageBusHarness public messageBus;
    MessageBusManager public manager;

    address public authVerifier = makeAddr("authVerifier");
    address public gasFeePricing = makeAddr("gasFeePricing");
    address public owner = makeAddr("owner");

    address payable public gasRecipient = payable(makeAddr("gasRecipient"));

    function setUp() public {
        messageBus = new MessageBusHarness({_gasFeePricing: gasFeePricing, _authVerifier: authVerifier});
        manager = new MessageBusManager({messageBus_: address(messageBus), owner_: owner});
        messageBus.transferOwnership(address(manager));
    }

    function assertEq(MessageBusReceiver.TxStatus status, IManageable.TxStatus expected) internal {
        assertEq(uint8(status), uint8(expected));
    }

    function assertEq(IManageable.TxStatus status, IManageable.TxStatus expected) internal {
        assertEq(uint8(status), uint8(expected));
    }

    function toArray(
        bytes32 a,
        bytes32 b,
        bytes32 c
    ) public pure returns (bytes32[] memory arr) {
        arr = new bytes32[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    function test_updateMessageStatus_success() public {
        vm.prank(owner);
        manager.updateMessageStatus(MESSAGE_ID, IManageable.TxStatus.Success);
        assertEq(messageBus.getExecutedMessage(MESSAGE_ID), IManageable.TxStatus.Success);
    }

    function test_updateMessageStatus_fail() public {
        vm.prank(owner);
        manager.updateMessageStatus(MESSAGE_ID, IManageable.TxStatus.Fail);
        assertEq(messageBus.getExecutedMessage(MESSAGE_ID), IManageable.TxStatus.Fail);
    }

    function test_updateMessageStatus_null() public {
        messageBus.setMessageStatus(MESSAGE_ID, MessageBusReceiver.TxStatus.Fail);
        vm.prank(owner);
        manager.updateMessageStatus(MESSAGE_ID, IManageable.TxStatus.Null);
        assertEq(messageBus.getExecutedMessage(MESSAGE_ID), IManageable.TxStatus.Null);
    }

    function test_updateMessageStatus_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert();
        vm.prank(caller);
        manager.updateMessageStatus(MESSAGE_ID, IManageable.TxStatus.Success);
    }

    function test_updateAuthVerifier() public {
        vm.prank(owner);
        manager.updateAuthVerifier(address(1));
        assertEq(messageBus.authVerifier(), address(1));
    }

    function test_updateAuthVerifier_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert();
        vm.prank(caller);
        manager.updateAuthVerifier(address(1));
    }

    function test_withdrawGasFees() public {
        deal(address(messageBus), 123456);
        messageBus.setFees(123456);
        vm.prank(owner);
        manager.withdrawGasFees(gasRecipient);
        assertEq(address(messageBus).balance, 0);
        assertEq(gasRecipient.balance, 123456);
    }

    function test_withdrawGasFees_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        deal(address(messageBus), 123456);
        messageBus.setFees(123456);
        vm.expectRevert();
        vm.prank(caller);
        manager.withdrawGasFees(gasRecipient);
    }

    function test_rescueGas() public {
        deal(address(messageBus), 123456);
        vm.prank(owner);
        manager.rescueGas(gasRecipient);
        assertEq(address(messageBus).balance, 0);
        assertEq(gasRecipient.balance, 123456);
    }

    function test_rescueGas_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        deal(address(messageBus), 123456);
        vm.expectRevert();
        vm.prank(caller);
        manager.rescueGas(gasRecipient);
    }

    function test_updateGasFeePricing() public {
        vm.prank(owner);
        manager.updateGasFeePricing(address(1));
        assertEq(messageBus.gasFeePricing(), address(1));
    }

    function test_updateGasFeePricing_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert();
        vm.prank(caller);
        manager.updateGasFeePricing(address(1));
    }

    function test_transferOwnership() public {
        vm.prank(owner);
        manager.transferOwnership(address(1));
        assertEq(manager.owner(), address(1));
    }

    function test_transferOwnership_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert();
        vm.prank(caller);
        manager.transferOwnership(address(1));
    }

    function test_transferMessageBusOwnership() public {
        vm.prank(owner);
        manager.transferMessageBusOwnership(address(1));
        assertEq(messageBus.owner(), address(1));
    }

    function test_transferMessageBusOwnership_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert();
        vm.prank(caller);
        manager.transferMessageBusOwnership(address(1));
    }

    function test_getExecutedMessage() public {
        messageBus.setMessageStatus(MESSAGE_ID, MessageBusReceiver.TxStatus.Success);
        assertEq(manager.getExecutedMessage(MESSAGE_ID), IManageable.TxStatus.Success);
        messageBus.setMessageStatus(MESSAGE_ID, MessageBusReceiver.TxStatus.Fail);
        assertEq(manager.getExecutedMessage(MESSAGE_ID), IManageable.TxStatus.Fail);
        messageBus.setMessageStatus(MESSAGE_ID, MessageBusReceiver.TxStatus.Null);
        assertEq(manager.getExecutedMessage(MESSAGE_ID), IManageable.TxStatus.Null);
    }

    function test_resetFailedMessages() public {
        bytes32[] memory messageIds = toArray("Test1", "Test2", "Test3");
        for (uint256 i = 0; i < messageIds.length; i++) {
            messageBus.setMessageStatus(messageIds[i], MessageBusReceiver.TxStatus.Fail);
        }
        vm.prank(owner);
        manager.resetFailedMessages(messageIds);
        for (uint256 i = 0; i < messageIds.length; i++) {
            assertEq(manager.getExecutedMessage(messageIds[i]), IManageable.TxStatus.Null);
            assertEq(messageBus.getExecutedMessage(messageIds[i]), IManageable.TxStatus.Null);
        }
    }

    function test_resetFailedMessages_revert_hasNullMessage() public {
        bytes32[] memory messageIds = toArray("Test1", "Test2", "Test3");
        messageBus.setMessageStatus(messageIds[0], MessageBusReceiver.TxStatus.Fail);
        messageBus.setMessageStatus(messageIds[1], MessageBusReceiver.TxStatus.Null);
        messageBus.setMessageStatus(messageIds[2], MessageBusReceiver.TxStatus.Fail);
        vm.expectRevert();
        vm.prank(owner);
        manager.resetFailedMessages(messageIds);
    }

    function test_resetFailedMessages_revert_hasSuccessMessage() public {
        bytes32[] memory messageIds = toArray("Test1", "Test2", "Test3");
        messageBus.setMessageStatus(messageIds[0], MessageBusReceiver.TxStatus.Fail);
        messageBus.setMessageStatus(messageIds[1], MessageBusReceiver.TxStatus.Fail);
        messageBus.setMessageStatus(messageIds[2], MessageBusReceiver.TxStatus.Success);
        vm.expectRevert();
        vm.prank(owner);
        manager.resetFailedMessages(messageIds);
    }

    function test_resetFailedMessages_revert_callerNotOwner(address caller) public {
        vm.assume(caller != owner);
        bytes32[] memory messageIds = toArray("Test1", "Test2", "Test3");
        for (uint256 i = 0; i < messageIds.length; i++) {
            messageBus.setMessageStatus(messageIds[i], MessageBusReceiver.TxStatus.Fail);
        }
        vm.expectRevert();
        vm.prank(caller);
        manager.resetFailedMessages(messageIds);
    }
}
