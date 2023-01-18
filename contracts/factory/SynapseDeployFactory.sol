// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import {ISynapseDeployFactory} from "./interfaces/ISynapseDeployFactory.sol";

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";
import {Clones} from "@openzeppelin/contracts-4.5.0/proxy/Clones.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

/// @title Factory for deploying contracts to deterministic addresses via CREATE3
/// @author zefram.eth
/// @notice Enables deploying contracts using CREATE3. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
/// Modified by the Synapse contributors to enable deploying minimal proxies (clones) in a similar fashion.
contract SynapseDeployFactory is ISynapseDeployFactory {
    using Address for address;

    /// @inheritdoc ISynapseDeployFactory
    function deploy(bytes32 salt, bytes memory creationCode) external payable override returns (address deployed) {
        // Use salt that is unique for every deployer
        salt = _deployerSalt(msg.sender, salt);
        return CREATE3.deploy(salt, creationCode, msg.value);
    }

    /// @inheritdoc ISynapseDeployFactory
    function deployClone(
        bytes32 salt,
        address master,
        bytes calldata initData
    ) external returns (address deployed) {
        // Use salt that is unique for every deployer
        salt = _deployerSalt(msg.sender, salt);
        // Setup a minimal proxy, using the master implementation
        deployed = Clones.cloneDeterministic(master, salt);
        // Do the initializer call, if requested
        if (initData.length != 0) {
            // This will bubble up the revert, if it happens during the function call
            deployed.functionCall(initData);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        PREDICT ADDRESS VIEWS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @inheritdoc ISynapseDeployFactory
    function predictAddress(address deployer, bytes32 salt) external view override returns (address deployed) {
        // Use salt that is unique for every deployer
        salt = _deployerSalt(deployer, salt);
        return CREATE3.getDeployed(salt);
    }

    /// @inheritdoc ISynapseDeployFactory
    function predictCloneAddress(
        address deployer,
        bytes32 salt,
        address master
    ) external view returns (address deployed) {
        // Use salt that is unique for every deployer
        salt = _deployerSalt(deployer, salt);
        return Clones.predictDeterministicAddress(master, salt);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns a unique salt for every (deployer, salt) tuple.
    function _deployerSalt(address deployer, bytes32 salt) internal pure returns (bytes32 deployerSalt) {
        // hash salt with the deployer address to give each deployer its own namespace
        return keccak256(abi.encodePacked(deployer, salt));
    }
}
