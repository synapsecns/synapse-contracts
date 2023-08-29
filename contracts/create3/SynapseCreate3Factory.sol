// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Create3Lib} from "./libs/Create3.sol";
import {ISynapseCreate3Factory} from "./interfaces/ISynapseCreate3Factory.sol";

/// @title Synapse Create3 Contract Factory
/// @author Synapse contributors
/// @author Modified from 0age (https://github.com/0age/metamorphic/blob/master/contracts/ImmutableCreate2Factory.sol)
/// @notice This contract provides a way to deploy contracts to the deterministic address, which
/// doesn't depend on the creation code (aka EIP-3171, aka "CREATE3").
/// Every deployer has access to their unique address deployment space of 2**96 addresses.
contract SynapseCreate3Factory is ISynapseCreate3Factory {
    error SynapseCreate3Factory__UnauthorizedDeployer(address deployer, address authorized);

    /// @dev Modifier to check that the first 20 bytes of the salt are equal to the caller's address.
    /// This is used to prevent unauthorized deploys.
    /// Note: unlike ImmutableCreate2Factory, this check could NOT be bypassed by setting
    /// the first 20 bytes of the salt to zero. This is done to prevent the inevitable footguns,
    /// as unlike create2, the resulting address does not depend on the creation code.
    modifier containsCaller(bytes32 salt) {
        address authorized = address(bytes20(salt));
        if (authorized != msg.sender) {
            revert SynapseCreate3Factory__UnauthorizedDeployer(msg.sender, authorized);
        }
        _;
    }

    /// @inheritdoc ISynapseCreate3Factory
    function safeCreate3(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory initData
    ) external payable containsCaller(salt) returns (address deployedAt) {}

    /// @inheritdoc ISynapseCreate3Factory
    function predictAddress(bytes32 salt) external view returns (address) {
        return Create3Lib.predictAddress(salt);
    }
}
