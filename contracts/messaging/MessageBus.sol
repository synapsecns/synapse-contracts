// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MessageBusSender.sol";
import "./MessageBusReceiver.sol";

contract MessageBus is MessageBusSender, MessageBusReceiver {
    constructor(IAuthVerifier _verifier, IMessageExecutor _executor) {
        verifier = _verifier;
        executor = _executor;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         UPDATING: ONLY OWNER                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function updateAuthVerifier(IAuthVerifier _verifier) external onlyOwner {
        require(address(_verifier) != address(0), "Cannot set to 0");
        verifier = _verifier;
    }

    function updateMessageExecutor(IMessageExecutor _executor) external onlyOwner {
        require(address(_executor) != address(0), "Cannot set to 0");
        executor = _executor;
    }

    // TODO: how useful is that, if contract is immutable?
    function updateMessageStatus(bytes32 _messageId, TxStatus _status) external onlyOwner {
        executedMessages[_messageId] = _status;
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
