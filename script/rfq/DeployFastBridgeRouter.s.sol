// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter} from "../../contracts/rfq/FastBridgeRouter.sol";

import {console2, BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract DeployFastBridgeRouter is BasicSynapseScript {
    string public constant FAST_BRIDGE_ROUTER = "FastBridgeRouter";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployCreate2` as callback to deploy the contract with CREATE2
        // This will load deployment salt from the pre-saved list, if there's an entry for the contract
        deployAndSave({
            contractName: FAST_BRIDGE_ROUTER,
            constructorArgs: abi.encode(msg.sender),
            deployCode: deployCreate2
        });
        vm.stopBroadcast();
    }
}
