// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TraderJoeV21Module} from "../../../../../contracts/router/modules/pool/traderjoe/TraderJoeV21Module.sol";

import {BasicSynapseScript} from "../../../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployTraderJoeV21Module is BasicSynapseScript {
    using stdJson for string;

    string public constant TRADER_JOE_V21_MODULE = "TraderJoeV21Module";

    address public lbRouter;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        readConfig();
        // Use `deployTraderJoeV21Module` as callback to deploy the contract
        address module = deployAndSave({
            contractName: TRADER_JOE_V21_MODULE,
            deployContract: deployTraderJoeV21Module
        });
        vm.stopBroadcast();
        // Verify the module was deployed correctly
        require(address(TraderJoeV21Module(module).lbRouter()) == lbRouter, "!lbRouter");
    }

    function readConfig() internal {
        string memory config = getDeployConfig(TRADER_JOE_V21_MODULE);
        lbRouter = config.readAddress(".lbRouter");
    }

    /// @notice Callback function to deploy the TraderJoeV21Module contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployTraderJoeV21Module() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new TraderJoeV21Module(lbRouter));
        constructorArgs = abi.encode(lbRouter);
    }
}
