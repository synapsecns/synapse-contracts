// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/MessageBus.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract MessageBusTest is Test {
    MessageBus public messageBus;
    AuthVerifier public authVerifier;

    function setUp() public {
        authVerifier = new AuthVerifier(address(1337));
        messageBus = new MessageBus(address(messageBus), address(authVerifier));
    }

    function testUnauthorizedPauseUnpause() public {
        // try pausing from unauthorized address
        vm.prank(address(999));
        vm.expectRevert("Ownable: caller is not the owner");
        messageBus.pause();

        // switch to authorized address, pause
        vm.prank(address(this));
        messageBus.pause();

        // try pausing from unauthorized address
        vm.prank(address(999));
        vm.expectRevert("Ownable: caller is not the owner");
        messageBus.unpause();

        // try unpausing from correct address
        vm.prank(address(this));
        messageBus.unpause();
    }

    function testPausedMessageReceive() public {
        // pause the contract
        vm.prank(address(this));
        messageBus.pause();

        uint256 srcChainId = 1;
        bytes32 srcAddress = addressToBytes32(address(1338));
        address dstAddress = address(
            0x2796317b0fF8538F253012862c06787Adfb8cEb6
        );
        uint256 nonce = 0;
        bytes memory message = bytes("");
        bytes32 messageId = keccak256("testMessageId");

        vm.prank(address(999));
        vm.expectRevert("Pausable: paused");

        messageBus.executeMessage(
            srcChainId,
            srcAddress,
            dstAddress,
            200000,
            nonce,
            message,
            messageId
        );
    }

    function testPausedMessageSend() public {
        // pause the contract
        vm.prank(address(this));
        messageBus.pause();

        vm.expectRevert("Pausable: paused");
        bytes32 receiverAddress = addressToBytes32(address(1337));
        messageBus.sendMessage{value: 4}(
            receiverAddress,
            121,
            bytes(""),
            bytes("")
        );
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
