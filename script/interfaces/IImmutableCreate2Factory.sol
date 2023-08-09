// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes memory initializationCode)
        external
        payable
        returns (address deploymentAddress);
}
