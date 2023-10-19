// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTPRouter} from "../../contracts/cctp/SynapseCCTPRouter.sol";

import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";
import {console, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract DeploySynapseCCTProuterScript is BasicSynapseScript {
    using stdJson for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant SYNAPSE_CCTP_ROUTER = "SynapseCCTPRouter";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deploySynapseCCTPRouter` as callback to deploy the contract
        deployAndSave({contractName: SYNAPSE_CCTP_ROUTER, deployContract: deploySynapseCCTPRouter});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the SynapseCCTPRouter contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deploySynapseCCTPRouter() internal returns (address deployedAt, bytes memory constructorArgs) {
        address synapseCCTP = getDeploymentAddress(SYNAPSE_CCTP);
        deployedAt = address(new SynapseCCTPRouter(synapseCCTP));
        constructorArgs = abi.encode(synapseCCTP);
    }
}
