// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {FactoryDeployer} from "../../contracts/factory/FactoryDeployer.sol";
import {ISynapseDeployFactory} from "../../contracts/factory/interfaces/ISynapseDeployFactory.sol";

import {SynapseScript} from "./SynapseScript.sol";

abstract contract DeployScript is FactoryDeployer, SynapseScript {
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

    function setupFactory() public {
        // TODO: deploy actual Factory on the same address everywhere and use it instead
        // address _factory = vm.env("SYNAPSE_FACTORY_ADDRESS");
        // For now this is just for the anvil deployment / runDry tests
        address _factory = deployCode("SynapseDeployFactory.sol");
        console.log("Using deploy factory: %s", address(_factory));
        setupFactory(ISynapseDeployFactory(_factory));
    }

    function loadDeploySalt(
        string memory deploymentName,
        string memory envKey,
        bytes32 defaultSalt
    ) public returns (bytes32 salt) {
        salt = vm.envOr(envKey, defaultSalt);
        logPredictedAddress(deploymentName, salt);
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

    /**
     * @notice Deploys a contract using the Synapse Deploy Factory
     * and saves it in the current chain deployments.
     * @dev Contract code will be fetched from artifact of `contractName`
     * @param contractName      Name for getting bytecode from the artifacts directory, and saving the deployment
     * @param salt              Salt for determining the deployed contract address
     * @param constructorArgs   ABI-encoded constructor args for the deployment
     * @param initData          Calldata for initializer call (ignored if empty)
     * @return deployment       Address of the deployed contract
     */
    function deploy(
        string memory contractName,
        bytes32 salt,
        bytes memory constructorArgs,
        bytes memory initData
    ) public returns (address deployment) {
        deployment = deploy(contractName, contractName, salt, constructorArgs, initData);
    }

    /**
     * @notice Deploys a contract using the Synapse Deploy Factory
     * and saves it in the current chain deployments.
     * @dev Contract code will be fetched from artifact of `contractName`
     * @param contractName      Name for getting bytecode from the artifacts directory
     * @param deploymentName    Name for saving the deployment
     * @param salt              Salt for determining the deployed contract address
     * @param constructorArgs   ABI-encoded constructor args for the deployment
     * @param initData          Calldata for initializer call (ignored if empty)
     * @return deployment       Address of the deployed contract
     */
    function deploy(
        string memory contractName,
        string memory deploymentName,
        bytes32 salt,
        bytes memory constructorArgs,
        bytes memory initData
    ) public returns (address deployment) {
        bytes memory contractCode = loadBytecode(contractName);
        deployment = deploy(deploymentName, salt, contractCode, constructorArgs, initData);
    }

    /**
     * @notice Deploys a contract using the Synapse Deploy Factory
     * and saves it in the current chain deployments.
     * @param deploymentName    Name for saving the deployment
     * @param salt              Salt for determining the deployed contract address
     * @param contractCode      Contract bytecode for the deployment
     * @param constructorArgs   ABI-encoded constructor args for the deployment
     * @param initData          Calldata for initializer call (ignored if empty)
     * @return deployment       Address of the deployed contract
     */
    function deploy(
        string memory deploymentName,
        bytes32 salt,
        bytes memory contractCode,
        bytes memory constructorArgs,
        bytes memory initData
    ) public returns (address deployment) {
        // Deploy contract with given constructor args
        deployment = deployContract(salt, abi.encodePacked(contractCode, constructorArgs), initData);
        // Save it in the deployments
        saveDeployment(deploymentName, deployment);
    }

    /**
     * @notice Logs the predicted address for a contract deployment using Synapse Deploy Factory.
     * @param deploymentName    Name that will be used for saving the deployment
     * @param salt              Salt for determining the deployed contract address
     */
    function logPredictedAddress(string memory deploymentName, bytes32 salt) public view {
        address predicted = factory.predictAddress(broadcasterAddress, salt);
        console.log("Predicted address for %s: %s", deploymentName, predicted);
    }

    /**
     * @notice Deploys a minimal proxy using the Synapse Deploy Factory
     * and saves it in the current chain deployments.
     * @dev Will revert, if `masterName` is not deployed onto the current chain.
     * @param deploymentName    Name that will be used for saving the deployment
     * @param salt              Salt for determining the deployed contract address
     * @param masterName        Name of the master implementation contract
     * @param initData          Data for the initializer call
     */
    function deployClone(
        string memory deploymentName,
        bytes32 salt,
        string memory masterName,
        bytes memory initData
    ) public returns (address deployment) {
        // Load address of master implementation on the current chain
        address master = loadDeployment(masterName);
        // Deploy a minimal proxy and call the initializer
        deployment = deployCloneContract(salt, master, initData);
        // Save it in the deployments
        saveDeployment(deploymentName, deployment);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             DEPLOYMENTS                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Saves the deployment JSON for a deployed contract.
    function saveDeployment(string memory contractName, address deployedAt) public {
        saveDeployment(contractName, deployedAt, "");
    }

    /// @notice Saves the deployment JSON for a deployed contract.
    function saveDeployment(
        string memory contractName,
        address deployedAt,
        bytes memory constructorArgs
    ) public {
        console.log("Deployed: [%s] on [%s] at %s", contractName, chain, deployedAt);
        // Do nothing if script isn't broadcasted
        if (!isBroadcasted) return;
        // Otherwise, save the deployment JSON
        string memory deployment = "deployment";
        // First, write only the deployment address and constructor args (should they be present)
        if (constructorArgs.length != 0) deployment.serialize("constructorArgs", constructorArgs);
        deployment = deployment.serialize("address", deployedAt);
        deployment.write(_deploymentPath(contractName));
        sortJSON(_deploymentPath(contractName));
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
        inputs[5] = _deploymentPath(contractName);
        bytes memory full = vm.ffi(inputs);
        // Finally, print the updated deployment JSON
        string(full).write(_deploymentPath(contractName));
    }
}
