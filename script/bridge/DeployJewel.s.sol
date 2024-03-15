// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseERC20Factory} from "../../contracts/bridge/SynapseERC20Factory.sol";
import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";

import {console2, BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract DeployJEWEL is BasicSynapseScript {
    string public constant SYNAPSE_ERC20_FACTORY = "SynapseERC20Factory";
    string public constant SYNAPSE_ERC20 = "SynapseERC20";
    string public constant SYNAPSE_BRIDGE = "SynapseERC20";
    string public constant MULTISIG = "DevMultisig";

    SynapseERC20Factory public erc20Factory;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Get addresses
        address factoryDeployment = getDeploymentAddress(SYNAPSE_ERC20_FACTORY);
        address erc20Deployment = getDeploymentAddress(SYNAPSE_ERC20);
        address bridge = getDeploymentAddress(SYNAPSE_BRIDGE);
        address multisig = getDeploymentAddress(MULTISIG);
        // Deploy
        erc20Factory = SynapseERC20Factory(factoryDeployment);
        address deployedAt = erc20Factory.deploy(erc20Deployment, "JEWEL", "JEWEL", 18, msg.sender);
        SynapseERC20 jewel = SynapseERC20(deployedAt);

        // Grant Roles
        jewel.grantRole(bytes32(0x00), multisig);
        jewel.grantRole(MINTER_ROLE, bridge);
        jewel.renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Verify roles
        require(jewel.hasRole(DEFAULT_ADMIN_ROLE, multisig), "Admin role not set correctly");
        require(jewel.hasRole(MINTER_ROLE, bridge), "Minter not set correctly");
        require(jewel.getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 1, "Admin count not set correctly");
        require(jewel.getRoleMemberCount(MINTER_ROLE) == 1, "Minter count not set correctly");

        saveDeployment("SynapseERC20", "JEWEL", deployedAt, "");

        vm.stopBroadcast();
    }
}
