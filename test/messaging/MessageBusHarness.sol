// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {MessageBus} from "../../contracts/messaging/MessageBus.sol";

// DO NOT USE THIS CONTRACT IN PRODUCTION
contract MessageBusHarness is MessageBus {
    constructor(address _gasFeePricing, address _authVerifier) MessageBus(_gasFeePricing, _authVerifier) {}

    function setMessageStatus(bytes32 messageId, TxStatus status) external {
        executedMessages[messageId] = status;
    }

    function setFees(uint256 fees_) external {
        fees = fees_;
    }
}
