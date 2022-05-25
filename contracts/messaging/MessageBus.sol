// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MessageBusSender.sol";
import "./MessageBusReceiver.sol";

contract MessageBus is MessageBusSender, MessageBusReceiver {
    constructor(
        IGasFeePricing _pricing,
        IAuthVerifier _verifier,
        IMessageExecutor _executor
    ) {
        pricing = _pricing;
        verifier = _verifier;
        executor = _executor;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               PAUSABLE                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
