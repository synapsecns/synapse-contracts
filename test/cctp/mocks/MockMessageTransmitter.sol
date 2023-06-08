// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MessageTransmitterEvents} from "../../../contracts/cctp/events/MessageTransmitterEvents.sol";
import {IMessageTransmitter} from "../../../contracts/cctp/interfaces/IMessageTransmitter.sol";
import {ITokenMessenger} from "../../../contracts/cctp/interfaces/ITokenMessenger.sol";

/// Very simplified version of CCTP's MessageTransmitter for testing purposes.
contract MockMessageTransmitter is MessageTransmitterEvents, IMessageTransmitter {
    uint32 public override localDomain;
    uint64 public override nextAvailableNonce;

    event SignatureReceived(bytes signature);

    constructor(uint32 localDomain_) {
        localDomain = localDomain_;
        nextAvailableNonce = 1;
    }

    function sendMessageWithCaller(
        uint32,
        bytes32 recipient,
        bytes32 destinationCaller,
        bytes calldata messageBody
    ) external returns (uint64 reservedNonce) {
        reservedNonce = nextAvailableNonce;
        nextAvailableNonce = reservedNonce + 1;
        emit MessageSent(
            formatMessage({
                remoteDomain: localDomain,
                sender: msg.sender,
                recipient: address(uint160(uint256(recipient))),
                destinationCaller: destinationCaller,
                messageBody: messageBody
            })
        );
    }

    function receiveMessage(bytes calldata message, bytes calldata signature) external returns (bool success) {
        require(signature.length % 65 == 0, "Invalid attestation length");
        (
            uint32 remoteDomain,
            bytes32 sender,
            address recipient,
            bytes32 destinationCaller,
            bytes memory messageBody
        ) = abi.decode(message, (uint32, bytes32, address, bytes32, bytes));
        if (destinationCaller != 0) {
            require(destinationCaller == bytes32(uint256(uint160(msg.sender))), "Invalid caller for message");
        }
        require(
            ITokenMessenger(recipient).handleReceiveMessage(remoteDomain, sender, messageBody),
            "handleReceiveMessage() failed"
        );
        emit SignatureReceived(signature);
        return true;
    }

    function formatMessage(
        uint32 remoteDomain,
        address sender,
        address recipient,
        bytes32 destinationCaller,
        bytes memory messageBody
    ) public pure returns (bytes memory message) {
        message = abi.encode(remoteDomain, sender, recipient, destinationCaller, messageBody);
    }
}
