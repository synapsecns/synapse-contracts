// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CurveV1Module} from "../../../../../contracts/router/modules/pool/curve/CurveV1Module.sol";

import {BasicSynapseScript} from "../../../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployCurveV1Module is BasicSynapseScript {
    string public constant CURVE_V1_MODULE = "CurveV1Module";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        deployAndSave({contractName: CURVE_V1_MODULE, deployContract: deployCurveV1Module});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the CurveV1Module contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployCurveV1Module() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new CurveV1Module());
        constructorArgs = "";
    }
}
