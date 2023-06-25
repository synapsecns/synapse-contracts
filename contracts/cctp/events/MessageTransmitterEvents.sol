// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract MessageTransmitterEvents {
    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(bytes message);

    /**
     * @notice Emitted when a new message is received
     * @param caller Caller (msg.sender) on destination domain
     * @param sourceDomain The source domain this message originated from
     * @param nonce The nonce unique to this message
     * @param sender The sender of this message
     * @param messageBody message body bytes
     */
    event MessageReceived(
        address indexed caller,
        uint32 sourceDomain,
        uint64 indexed nonce,
        bytes32 sender,
        bytes messageBody
    );
}
