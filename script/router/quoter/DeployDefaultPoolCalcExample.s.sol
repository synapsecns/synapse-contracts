// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

/// @notice This script deploys the DefaultPoolCalc contract in a non-deterministic way.
/// Script is written for demonstration purposes, use DeployDefaultPoolCalc.s.sol in production.
contract DeployDefaultPoolCalcExample is BasicSynapseScript {
    using StringUtils for string;

    string public constant DEFAULT_POOL_CALC = "DefaultPoolCalc";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployDefaultPoolCalc` as callback to deploy the contract
        deployAndSave({contractName: DEFAULT_POOL_CALC, constructorArgs: "", deployFn: deployDefaultPoolCalc});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the DefaultPoolCalc contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployFn(string memory contractName, bytes memory constructorArgs) internal returns (address deployedAt)`
    function deployDefaultPoolCalc(string memory contractName, bytes memory constructorArgs)
        internal
        returns (address deployedAt)
    {
        // Sanity check for demo purposes
        require(contractName.equals(DEFAULT_POOL_CALC), "Incorrect contract name");
        // Sanity check for demo purposes
        require(constructorArgs.length == 0, "Constructor args not supported");
        return address(new DefaultPoolCalc());
    }
}
