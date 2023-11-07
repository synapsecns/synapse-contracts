// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSynapseScript} from "./templates/BasicSynapse.s.sol";

/// @notice A generic deployment script, which deploys a contract with no constructor arguments,
/// and saves its deployment artifact in the deployments directory.
contract DeployNoArgs is BasicSynapseScript {
    function run(string memory contractName) external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deploy` as the callback function, which will extract the deployment bytecode
        // for `contractName` from the forge artifact and deploy it.
        deployAndSave({contractName: contractName, constructorArgs: "", deployCode: deploy});
        vm.stopBroadcast();
    }
}
