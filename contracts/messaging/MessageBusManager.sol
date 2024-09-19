// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IManager, IManageable} from "./interfaces/IManager.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract MessageBusManager is IManager, Ownable {
    address public immutable MESSAGE_BUS;

    constructor(address messageBus_, address owner_) {
        MESSAGE_BUS = messageBus_;
        transferOwnership(owner_);
    }

    function resetFailedMessages(bytes32[] calldata messageIds) external {
        // TODO: implement
    }

    // ═════════════════════════════════════════════ GENERIC MANAGING ══════════════════════════════════════════════════

    function updateMessageStatus(bytes32 messageId, TxStatus status) external onlyOwner {
        IManageable(MESSAGE_BUS).updateMessageStatus(messageId, status);
    }

    function updateAuthVerifier(address authVerifier) external onlyOwner {
        IManageable(MESSAGE_BUS).updateAuthVerifier(authVerifier);
    }

    function withdrawGasFees(address payable to) external onlyOwner {
        IManageable(MESSAGE_BUS).withdrawGasFees(to);
    }

    function rescueGas(address payable to) external onlyOwner {
        IManageable(MESSAGE_BUS).rescueGas(to);
    }

    function updateGasFeePricing(address gasFeePricing) external onlyOwner {
        IManageable(MESSAGE_BUS).updateGasFeePricing(gasFeePricing);
    }

    function transferMessageBusOwnership(address newOwner) external onlyOwner {
        Ownable(MESSAGE_BUS).transferOwnership(newOwner);
    }

    function getExecutedMessage(bytes32 messageId) public view returns (TxStatus) {
        return IManageable(MESSAGE_BUS).getExecutedMessage(messageId);
    }
}
