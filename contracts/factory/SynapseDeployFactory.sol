// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import {ISynapseDeployFactory} from "./interfaces/ISynapseDeployFactory.sol";

import {CREATE3} from "solmate/utils/CREATE3.sol";

/// @title Factory for deploying contracts to deterministic addresses via CREATE3
/// @author zefram.eth
/// @notice Enables deploying contracts using CREATE3. Each deployer (msg.sender) has
/// its own namespace for deployed addresses.
/// Modified by the Synapse contributors to enable deploying minimal proxies (clones) in a similar fashion.
contract SynapseDeployFactory is ISynapseDeployFactory {
    function deploy(bytes32 salt, bytes memory creationCode) external payable override returns (address deployed) {
        // Use salt that is unique for every deployer
        salt = _deployerSalt(msg.sender, salt);
        return CREATE3.deploy(salt, creationCode, msg.value);
    }

    function deployClone(
        bytes32 salt,
        address master,
        bytes calldata initData
    ) external returns (address deployed) {}

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        PREDICT ADDRESS VIEWS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function predictAddress(address deployer, bytes32 salt) external view override returns (address deployed) {
        // Use salt that is unique for every deployer
        salt = _deployerSalt(deployer, salt);
        return CREATE3.getDeployed(salt);
    }

    function predictCloneAddress(
        address deployer,
        bytes32 salt,
        address master
    ) external view returns (address deployed) {}

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _deployerSalt(address deployer, bytes32 salt) internal pure returns (bytes32 deployerSalt) {
        // hash salt with the deployer address to give each deployer its own namespace
        return keccak256(abi.encodePacked(deployer, salt));
    }
}