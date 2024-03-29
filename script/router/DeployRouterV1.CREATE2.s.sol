// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSynapseScript, console2} from "../templates/BasicSynapse.s.sol";

contract DeployRouterV1CREATE2 is BasicSynapseScript {
    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployCreate2` as callback to deploy the contract with CREATE2
        // This will load deployment salt from the pre-saved list, if there's an entry for the contract
        deployAndSave({
            contractName: "SynapseRouter",
            constructorArgs: getConstructorArgs(),
            deployCode: deploySolcGeneratedCreate2
        });
        vm.stopBroadcast();
    }

    function getConstructorArgs() internal returns (bytes memory constructorArgs) {
        address bridge = getDeploymentAddress("SynapseBridge");
        address owner = vm.envAddress("OWNER_ADDR");
        constructorArgs = abi.encode(bridge, owner);
    }
}
