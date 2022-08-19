// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;
import "./MessageBusSender.sol";
import "./MessageBusReceiver.sol";

contract MessageBus is MessageBusSender, MessageBusReceiver {
    constructor(address _gasFeePricing, address _authVerifier)
        MessageBusSender(_gasFeePricing)
        MessageBusReceiver(_authVerifier)
    {
        // silence linter without generating bytecode
        this;
    }

    // PAUSABLE FUNCTIONS ***/
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
