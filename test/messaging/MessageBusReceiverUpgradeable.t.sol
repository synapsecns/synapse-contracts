// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "src-messaging/MessageBusUpgradeable.sol";
import "src-messaging/AuthVerifier.sol";

import "@openzeppelin/contracts-4.5.0/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MessageBusReceiverUpgradeableTest is Test {
    MessageBusUpgradeable public messageBusReceiver;
    AuthVerifier public authVerifier;

    function setUp() public {
        authVerifier = new AuthVerifier(address(1337));
        MessageBusUpgradeable impl = new MessageBusUpgradeable();
        // Setup proxy with needed logic and custom admin,
        // we don't need to upgrade anything, so no need to setup ProxyAdmin
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(420), bytes(""));
        messageBusReceiver = MessageBusUpgradeable(address(proxy));
        messageBusReceiver.initialize(address(0), address(authVerifier));
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function testAddressToBytes32() public {
        address _address = 0xDE03e73c3785cE086ca85C6315Df376A4A64C84b;
        emit log_named_bytes32("bytes32", addressToBytes32(_address));
        emit log_named_address("address", _address);
    }

    function bytes32ToAddress(bytes32 bys) public pure returns (address) {
        return address(uint160(uint256(bys)));
    }

    // function testComputeMessageId() public returns(bytes32) {
    //     uint256 srcChainId = 1;
    //     bytes32 srcAddress = addressToBytes32(address(1338));
    //     address dstAddress = address(0x2796317b0fF8538F253012862c06787Adfb8cEb6);
    //     uint256 nonce = 0;
    //     bytes memory message = bytes("");

    //     bytes32 expectedMessageId = keccak256(abi.encode(
    //         srcChainId, srcAddress, block.chainid, dstAddress, nonce, message
    //     ));

    //     bytes32 messageId = messageBusReceiver.computeMessageId(srcChainId, srcAddress, dstAddress, nonce, message);
    //     assertEq(messageId, expectedMessageId);
    //     return messageId;
    // }

    // Authorized actor can update status of messages, and they are set correctly
    function testAuthorizedUpdateMessageStatus() public {
        // bytes32 messageId = testComputeMessageId();
        bytes32 messageId = keccak256("testMessageId");
        MessageBusUpgradeable.TxStatus initialStatus = messageBusReceiver.getExecutedMessage(messageId);
        messageBusReceiver.updateMessageStatus(messageId, MessageBusReceiverUpgradeable.TxStatus.Success);
        MessageBusUpgradeable.TxStatus finalStatus = messageBusReceiver.getExecutedMessage(messageId);
        assertGt(uint256(finalStatus), uint256(initialStatus));
    }

    function testUnauthorizedUpdateMessageStatus() public {
        bytes32 messageId = keccak256("testMessageId");
        vm.prank(address(9999));
        vm.expectRevert("Ownable: caller is not the owner");
        messageBusReceiver.updateMessageStatus(messageId, MessageBusReceiverUpgradeable.TxStatus.Success);
    }

    // Authorized actor can update AuthVerifeir library, and it sets correctly
    function testAuthorizedUpdateAuthVerifier() public {
        messageBusReceiver.updateAuthVerifier(address(1));
        assertEq(messageBusReceiver.authVerifier(), address(1));
    }

    function testUnauthorizedUpdateAuthVerifier() public {
        vm.prank(address(9999));
        vm.expectRevert("Ownable: caller is not the owner");
        messageBusReceiver.updateAuthVerifier(address(1));
    }

    function testUnauthorizedMessageSender() public {
        uint256 srcChainId = 1;
        bytes32 srcAddress = addressToBytes32(address(1338));
        address dstAddress = address(0x2796317b0fF8538F253012862c06787Adfb8cEb6);
        uint256 nonce = 0;
        bytes memory message = bytes("");
        bytes32 messageId = keccak256("testMessageId");

        vm.prank(address(999));
        vm.expectRevert("Unauthenticated caller");
        messageBusReceiver.executeMessage(srcChainId, srcAddress, dstAddress, 200000, nonce, message, messageId);
    }
}
