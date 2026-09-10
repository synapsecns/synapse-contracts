// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";
import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";

contract DeploySynapseToken is BasicSynapseScript {
    using StringUtils for string;

    address public synapseERC20Impl;
    SynapseERC20 public token;

    function run() external {
        setUp();
        vm.startBroadcast(msg.sender);
        synapseERC20Impl = deployAndSave({contractName: "SynapseERC20", deployContract: deploySynapseERC20});
        assertContractCodeExists("SynapseERC20", synapseERC20Impl);
        token = SynapseERC20(
            deployAndSaveAs({contractName: "SynapseERC20", contractAlias: "SynapseToken", deployContract: deployToken})
        );
        vm.stopBroadcast();

        checkToken();
    }

    function deploySynapseERC20() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new SynapseERC20());
        constructorArgs = "";
    }

    function deployToken() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = Clones.clone(synapseERC20Impl);
        // Broadcasting creates separate deployment and initialization transactions.
        // If initialization is front-run, discard this deployment and deploy a new clone.
        SynapseERC20(deployedAt).initialize("Synapse", "SYN", 18, msg.sender);
        constructorArgs = "";
    }

    function checkToken() internal view {
        require(token.name().equals("Synapse"), "Incorrect token name");
        require(token.symbol().equals("SYN"), "Incorrect token symbol");
        require(token.decimals() == 18, "Incorrect token decimals");
    }
}
