// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IManager} from "./interfaces/IManager.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract MessageBusManager is IManager, Ownable {
    constructor(address messageBus_, address owner_) {
        // TODO: implement
    }

    function resetFailedMessages(bytes32[] calldata messageIds) external {
        // TODO: implement
    }

    // ═════════════════════════════════════════════ GENERIC MANAGING ══════════════════════════════════════════════════

    function updateMessageStatus(bytes32 messageId, TxStatus status) external {
        // TODO: implement
    }

    function updateAuthVerifier(address authVerifier) external {
        // TODO: implement
    }

    function withdrawGasFees(address payable to) external {
        // TODO: implement
    }

    function rescueGas(address payable to) external {
        // TODO: implement
    }

    function updateGasFeePricing(address gasFeePricing) external {
        // TODO: implement
    }

    function transferMessageBusOwnership(address newOwner) external {
        // TODO: implement
    }

    function getExecutedMessage(bytes32 messageId) public view returns (TxStatus) {
        // TODO: implement
    }
}
