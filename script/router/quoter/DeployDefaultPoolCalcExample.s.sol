// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {BasicSynapseScript} from "../../templates/BasicSynapse.s.sol";

/// @notice This script deploys the DefaultPoolCalc contract in a non-deterministic way.
/// Script is written for demonstration purposes, use DeployDefaultPoolCalc.s.sol in production.
contract DeployDefaultPoolCalcExample is BasicSynapseScript {
    string public constant DEFAULT_POOL_CALC = "DefaultPoolCalc";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployDefaultPoolCalc` as callback to deploy the contract
        deployAndSave({contractName: DEFAULT_POOL_CALC, deployContract: deployDefaultPoolCalc});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the DefaultPoolCalc contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployDefaultPoolCalc() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new DefaultPoolCalc());
        constructorArgs = "";
    }
}
