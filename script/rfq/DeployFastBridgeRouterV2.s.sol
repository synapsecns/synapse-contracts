// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract DeployFastBridgeRouter is BasicSynapseScript {
    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployCreate2` as callback to deploy the contract with CREATE2
        // This will load deployment salt from the pre-saved list, if there's an entry for the contract
        deployAndSave({
            contractName: "FastBridgeRouterV2",
            constructorArgs: abi.encode(msg.sender),
            deployCode: deployCreate2
        });
        vm.stopBroadcast();
    }
}
