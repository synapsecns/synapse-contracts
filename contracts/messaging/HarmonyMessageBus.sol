// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MessageBus.sol";

contract HarmonyMessageBus is MessageBus {
    uint256 private constant CHAIN_ID = 1666600000;

    constructor(IAuthVerifier _verifier, IMessageExecutor _executor) MessageBus(_verifier, _executor) {
        this;
    }

    function _chainId() internal pure override returns (uint256) {
        return CHAIN_ID;
    }
}
