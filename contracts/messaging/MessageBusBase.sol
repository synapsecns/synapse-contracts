// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interfaces/IAuthVerifier.sol";
import "./interfaces/IMessageExecutor.sol";

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "@openzeppelin/contracts-4.5.0/security/Pausable.sol";

contract MessageBusBase is Ownable, Pausable {
    /// @dev Contract used for executing received messages,
    /// and for calculating a fee for sending a message
    IMessageExecutor public executor;

    /// @dev Contract used for authenticating validator address
    IAuthVerifier public verifier;
}
