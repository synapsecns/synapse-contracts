// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {SynapseScript} from "./SynapseScript.sol";

abstract contract DeployScript is SynapseScript {
    using stdJson for string;

    /// @notice Execute the script, which will be broadcasted.
    function run() external {
        execute(true);
    }

    /// @notice Execute the script, which won't be broadcasted.
    function runDry() external {
        execute(false);
    }

    /// @notice Logic for executing the script
    function execute(bool isBroadcasted) public virtual;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                SETUP                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function setupDeployerPK() public {
        setupPK("DEPLOYER_PRIVATE_KEY");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                 MISC                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function skipToNonce(uint256 nonce) public {
        uint256 curNonce = vm.getNonce(broadcasterAddress);
        require(curNonce <= nonce, "Nonce misaligned");
        while (curNonce < nonce) {
            console.log("Skipping nonce: %s", curNonce);
            payable(broadcasterAddress).transfer(0);
            ++curNonce;
        }
        // Sanity check
        require(vm.getNonce(broadcasterAddress) == nonce, "Failed to align the nonce");
        console.log("Deployer nonce is %s", nonce);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               DEPLOYS                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function deployBytecode(string memory contractName, bytes memory constructorArgs)
        public
        returns (address deployment)
    {
        console.log("Deploying manually: %s", contractName);
        console.logBytes(constructorArgs);
        bytes memory bytecode = abi.encodePacked(loadGeneratedBytecode(contractName), constructorArgs);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            deployment := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(deployment != address(0), "Deployment failed");
        saveDeployment(contractName, deployment, constructorArgs);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             DEPLOYMENTS                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Saves the deployment JSON for a deployed contract.
    function saveDeployment(string memory contractName, address deployedAt) public {
        saveDeployment(contractName, deployedAt, "");
    }

    /// @notice Saves the deployment JSON for a deployed contract.
    /// This is done optimistically, as the script doesn't have information whether
    /// the actual deployment went fine.
    /// "Fresh deployments" are expected to be verified in an external script.
    function saveDeployment(
        string memory contractName,
        address deployedAt,
        bytes memory constructorArgs
    ) public {
        console.log("Deployed: [%s] on [%s] at %s", contractName, chain, deployedAt);
        // Do nothing if script isn't broadcasted
        if (!isBroadcasted) return;
        string memory freshFN = _freshDeploymentPath(contractName);
        // Otherwise, save the deployment JSON
        string memory deployment = "deployment";
        // First, write only the deployment address and constructor args (should they be present)
        if (constructorArgs.length != 0) deployment.serialize("constructorArgs", constructorArgs);
        deployment = deployment.serialize("address", deployedAt);
        deployment.write(freshFN);
        sortJSON(freshFN);
        // Then, initiate the jq command to add "abi" as the next key
        // This makes sure that "address" value is printed first later
        string[] memory inputs = new string[](6);
        inputs[0] = "jq";
        // Read the full artifact file into $artifact variable
        inputs[1] = "--argfile";
        inputs[2] = "artifact";
        inputs[3] = _artifactPath(contractName);
        // Set value for ".abi" key to artifact's ABI
        inputs[4] = ".abi = $artifact.abi";
        inputs[5] = freshFN;
        bytes memory full = vm.ffi(inputs);
        // Finally, print the updated deployment JSON
        string(full).write(freshFN);
    }
}
