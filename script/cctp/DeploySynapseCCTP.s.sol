// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger, SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";
import {stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract DeploySynapseCCTP is BasicSynapseScript {
    using stdJson for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";

    address public tokenMessenger;
    address public owner;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        bytes memory constructorArgs = loadConfig();
        vm.startBroadcast();
        // Use CREATE2 to deploy the contract with zero salt to prevent collisions
        setDeploymentSalt(0);
        address deployed = deployAndSave({
            contractName: SYNAPSE_CCTP,
            constructorArgs: constructorArgs,
            deployCode: deployCreate2
        });
        vm.stopBroadcast();
        // Sanity checks
        require(SynapseCCTP(deployed).owner() == owner, "Failed to set owner");
        require(address(SynapseCCTP(deployed).tokenMessenger()) == tokenMessenger, "Failed to set tokenMessenger");
    }

    function loadConfig() public returns (bytes memory constructorArgs) {
        string memory config = getDeployConfig(SYNAPSE_CCTP);
        // Read tokenMessenger from config
        tokenMessenger = config.readAddress(".tokenMessenger");
        require(tokenMessenger != address(0), "TokenMessenger not set");
        // Read owner address from .env
        owner = vm.envAddress("OWNER_ADDR");
        require(owner != address(0), "Owner not set");
        printLog("Using [tokenMessenger = %s] [owner = %s]", tokenMessenger, owner);
        constructorArgs = abi.encode(tokenMessenger, owner);
    }
}
