// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {MockSwap} from "../../../contracts/bridge/wrappers/swap/MockSwap.sol";
import {BasicSynapseScript} from "../../templates/BasicSynapse.s.sol";

contract DeployMockSwap is BasicSynapseScript {
    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        deployAndSave({contractName: "MockSwap", deployContract: deployMockSwap});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the MockSwap contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployMockSwap() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new MockSwap());
        constructorArgs = "";
    }
}
