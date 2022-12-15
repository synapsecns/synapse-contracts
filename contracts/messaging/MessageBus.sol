// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "./MessageBusSender.sol";
import "./MessageBusReceiver.sol";

contract MessageBus is MessageBusSender, MessageBusReceiver {
    constructor(address _gasFeePricing, address _authVerifier)
        MessageBusSender(_gasFeePricing)
        MessageBusReceiver(_authVerifier)
    {}
}
