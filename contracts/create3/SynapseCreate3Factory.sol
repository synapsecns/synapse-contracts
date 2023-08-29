// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseCreate3Factory} from "./interfaces/ISynapseCreate3Factory.sol";

/// @title Synapse Create3 Contract Factory
/// @author Synapse contributors
/// @author Modified from 0age (https://github.com/0age/metamorphic/blob/master/contracts/ImmutableCreate2Factory.sol)
/// @notice This contract provides a way to deploy contracts to the deterministic address, which
/// doesn't depend on the creation code (aka EIP-3171, aka "CREATE3").
/// Every deployer has access to their unique address deployment space of 2**96 addresses.
contract SynapseCreate3Factory is ISynapseCreate3Factory {
    /// @inheritdoc ISynapseCreate3Factory
    function safeCreate3(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory initData
    ) external payable returns (address deployedAt) {}

    /// @inheritdoc ISynapseCreate3Factory
    function predictAddress(bytes32 salt) external view returns (address) {}
}
