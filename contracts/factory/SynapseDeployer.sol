// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseDeployFactory} from "./interfaces/ISynapseDeployFactory.sol";

import {AccessControl} from "@openzeppelin/contracts-4.5.0/access/AccessControl.sol";

/// @title Permissioned factory for deterministic deployments via CREATE3
/// @author Synapse Contributors
/// @notice Enables deploying contracts using CREATE3. All deployers have a common
/// namespace for deployed addresses, thus the deployment process is permissioned.
/// Contract admin can add and remove whitelisted deployers by granting or revoking "DEPLOYER ROLE".
/// Whitelisted deployers have to coordinate their efforts in order not to reuse the same salt
/// for different contracts on different chains.
/// Both permissioned SynapseDeployer and permisionless SynapseDeployFactory have to be deployed
/// to the same address on all chains for this to work properly.
contract SynapseDeployer is AccessControl, ISynapseDeployFactory {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    ISynapseDeployFactory public immutable factory;

    constructor(ISynapseDeployFactory factory_, address admin) {
        factory = factory_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @inheritdoc ISynapseDeployFactory
    function deploy(
        bytes32 salt,
        bytes calldata creationCode,
        bytes calldata initData
    ) external payable override onlyRole(DEPLOYER_ROLE) returns (address deployed) {
        // Forward the call to the Synapse Factory
        // Only calls from authorized (DEPLOYER_ROLE) accounts are accepted
        return factory.deploy{value: msg.value}(salt, creationCode, initData);
    }

    /// @inheritdoc ISynapseDeployFactory
    function predictAddress(address, bytes32 salt) external view override returns (address deployed) {
        // Forward the call to the Synapse Factory: this contract is the deployer, not msg.sender
        return factory.predictAddress(address(this), salt);
    }
}
