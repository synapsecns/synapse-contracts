// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {StringUtils} from "./StringUtils.sol";

import {stdJson} from "forge-std/Script.sol";
import {CommonBase} from "forge-std/Base.sol";

/// @notice A collection of basic stateless utility functions used by Synapse scripts.
abstract contract BasicUtils is CommonBase {
    using StringUtils for string;
    using stdJson for string;

    string internal constant ARTIFACTS = "artifacts/";
    string internal constant FRESH_DEPLOYMENTS = ".deployments/";
    string internal constant DEPLOYMENTS = "deployments/";
    string internal constant DEPLOY_CONFIGS = "script/configs/";

    /// @notice Child contract should override this function to print logs.
    function printLog(string memory message) internal virtual;

    // ══════════════════════════════════════════════ DATA GENERATION ══════════════════════════════════════════════════

    /// @notice Produces a JSON string that can be used to save a contract deployment.
    /// Note: contract ABI is not included in the output.
    function serializeDeploymentData(address deployedAt, bytes memory constructorArgs)
        internal
        returns (string memory data)
    {
        data = "deployment";
        data.serialize("address", deployedAt);
        return serializeBytes(data, "constructorArgs", constructorArgs);
    }

    /// @notice Serializes a bytes value to a JSON string. Uses "0x" as the default value.
    function serializeBytes(
        string memory json,
        string memory key,
        bytes memory value
    ) internal returns (string memory) {
        if (value.length == 0) {
            return json.serialize(key, string("0x"));
        } else {
            return json.serialize(key, value);
        }
    }

    // ═══════════════════════════════════════════════ DATA WRITERS ════════════════════════════════════════════════════

    /// @notice Writes a JSON data to a file, and prints a log message.
    function saveJson(
        string memory descriptionLog,
        string memory path,
        string memory data
    ) internal {
        printLog(descriptionLog);
        data.write(path);
    }

    /// @notice Saves the deployment JSON for a contract on a given chain under the specified alias.
    /// Example: contractName = "LinkedPool", contractAlias = "LinkedPool.USDC"
    /// Note: writes to the FRESH deployment path, which is moved to the correct location after the contract is deployed.
    /// Note: requires ffi to be turned on, and jq to be installed.
    function saveDeploymentData(
        string memory chain,
        string memory contractName,
        string memory contractAlias,
        string memory dataWithoutABI
    ) internal {
        // Use contract alias to determine the deployment path
        string memory path = freshDeploymentPath(chain, contractAlias);
        // First save the deployment JSON without the ABI
        saveJson(StringUtils.concat("Saving deployment for ", contractAlias, " on ", chain), path, dataWithoutABI);
        // Then, append the ABI to the deployment JSON. This will put the "abi" key after the "address" key,
        // improving readability of the JSON file.
        // Use contract name to determine the artifact path
        string memory fullJson = addJsonKey({pathInput: artifactPath(contractName), pathOutput: path, key: ".abi"});
        // Finally, save the full deployment JSON
        fullJson.write(path);
    }

    /// @notice Saves the deploy config for a contract on a given chain.
    function saveDeployConfig(
        string memory chain,
        string memory contractName,
        string memory data
    ) internal {
        saveJson(
            StringUtils.concat("Saving deploy config for ", contractName, " on ", chain),
            deployConfigPath(chain, contractName),
            data
        );
    }

    /// @notice Saves the global config that is shared across all chains for a contract.
    function saveGlobalConfig(
        string memory contractName,
        string memory globalProperty,
        string memory data
    ) internal {
        saveJson(
            StringUtils.concat("Saving global config for ", contractName, ": ", globalProperty),
            globalConfigPath(contractName, globalProperty),
            data
        );
    }

    // ═════════════════════════════════════════════ ARTIFACTS GETTERS ═════════════════════════════════════════════════

    /// @notice Returns the full contract artifact JSON generated by forge.
    function getContractArtifact(string memory contractName) internal view returns (string memory artifactJson) {
        return vm.readFile(artifactPath(contractName));
    }

    /// @notice Returns the contract bytecode extracted from the artifact generated by forge.
    function getContractBytecode(string memory contractName) internal returns (bytes memory bytecode) {
        return getContractArtifact(contractName).readBytes(".bytecode.object");
    }

    // ═════════════════════════════════════════════ CHAIN ID GETTERS ══════════════════════════════════════════════════

    /// @notice Returns the chain ID for a given chain by reading the chain ID file in the deployments directory.
    /// Reverts if the chain ID file doesn't exist.
    function getChainId(string memory chain) internal returns (uint256 chainId) {
        chainId = tryGetChainId(chain);
        require(chainId != 0, StringUtils.concat("Chain ID not found for ", chain));
    }

    /// @notice Returns the chain ID for a given chain by reading the chain ID file in the deployments directory.
    /// Returns 0 if the chain ID file doesn't exist.
    function tryGetChainId(string memory chain) internal returns (uint256 chainId) {
        string memory path = DEPLOYMENTS.concat(chain, "/.chainId");
        try vm.readLine(path) returns (string memory chainIdStr) {
            vm.closeFile(path);
            return chainIdStr.toUint();
        } catch {
            return 0;
        }
    }

    // ════════════════════════════════════════════ DEPLOYMENT GETTERS ═════════════════════════════════════════════════

    /// @notice Returns the deployment address for a contract on a given chain.
    /// Reverts if the contract is not deployed.
    function getDeploymentAddress(string memory chain, string memory contractName)
        internal
        returns (address deployment)
    {
        deployment = tryGetDeploymentAddress(chain, contractName);
        require(deployment != address(0), contractName.concat(" not deployed on ", chain));
    }

    function getConstructorArgs(string memory chain, string memory contractName)
        internal
        view
        returns (bytes memory constructorArgs)
    {
        string memory json = vm.readFile(deploymentPath(chain, contractName));
        return json.readBytes(".constructorArgs");
    }

    /// @notice Returns the deployment address for a contract on a given chain, if it exists.
    /// Returns address(0), if it doesn't exist.
    function tryGetDeploymentAddress(string memory chain, string memory contractName)
        internal
        returns (address deployment)
    {
        try vm.readFile(deploymentPath(chain, contractName)) returns (string memory json) {
            // We assume that if a deployment file exists, the contract is indeed deployed
            return json.readAddress(".address");
        } catch {
            return address(0);
        }
    }

    // ═══════════════════════════════════════════ DEPLOY CONFIG GETTERS ═══════════════════════════════════════════════

    /// @notice Returns the deploy config for a contract on a given chain.
    function getDeployConfig(string memory chain, string memory contractName)
        internal
        view
        returns (string memory deployConfigJson)
    {
        return vm.readFile(deployConfigPath(chain, contractName));
    }

    /// @notice Returns the global config that is shared across all chains for a contract.
    function getGlobalConfig(string memory contractName, string memory globalProperty)
        internal
        view
        returns (string memory globalConfigJson)
    {
        return vm.readFile(globalConfigPath(contractName, globalProperty));
    }

    // ═════════════════════════════════════════════ FILE PATH GETTERS ═════════════════════════════════════════════════

    /// @notice Returns the path to the contract artifact generated by forge.
    /// Example: "artifacts/SynapseRouter.sol/SynapseRouter.json"
    function artifactPath(string memory contractName) internal pure returns (string memory path) {
        return ARTIFACTS.concat(contractName, ".sol/", contractName, ".json");
    }

    /// @notice Returns the path to the SAVED deployment JSON for a contract.
    /// Example: "deployments/mainnet/SynapseRouter.json"
    function deploymentPath(string memory chain, string memory contractName)
        internal
        pure
        returns (string memory path)
    {
        return DEPLOYMENTS.concat(chain, "/", contractName, ".json");
    }

    /// @dev Returns the path to the FRESH contract deployment JSON for a contract.
    /// These are optimistically created before the contract is deployed during the script simulation.
    /// A separate bash script is responsible for moving these to the correct location after the contract is deployed.
    /// Example: ".deployments/mainnet/SynapseRouter.json"
    function freshDeploymentPath(string memory chain, string memory contractName)
        internal
        pure
        returns (string memory path)
    {
        return FRESH_DEPLOYMENTS.concat(chain, "/", contractName, ".json");
    }

    /// @notice Returns the path to the contract deployment config JSON for a contract on a given chain.
    /// Example: "script/configs/mainnet/SynapseRouter.dc.json"
    function deployConfigPath(string memory chain, string memory contractName)
        internal
        pure
        returns (string memory path)
    {
        return genericConfigPath({chain: chain, fileName: contractName.concat(".dc.json")});
    }

    /// @notice Returns the path to the generic contract config file for a contract on a given chain.
    function genericConfigPath(string memory chain, string memory fileName) internal pure returns (string memory path) {
        return DEPLOY_CONFIGS.concat(chain, "/", fileName);
    }

    /// @notice Returns the path to the global config JSON that is shared across all chains for a contract.
    /// Example: "script/configs/SynapseCCTP.chains.json"
    function globalConfigPath(string memory contractName, string memory globalProperty)
        internal
        pure
        returns (string memory path)
    {
        return DEPLOY_CONFIGS.concat(contractName, ".", globalProperty, ".json");
    }

    // ════════════════════════════════════════════════ FILE UTILS ═════════════════════════════════════════════════════

    /// @notice Checks if a file exists.
    function fileExists(string memory path) internal view returns (bool) {
        // Try getting the file's metadata, will revert if it doesn't exist
        try vm.fsMetadata(path) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Reads value associated with a key from the input JSON file, and then writes it to the output JSON file.
    /// Will overwrite the value in the output JSON file if it already exists, otherwise will append it.
    /// Note: requires ffi to be turned on, and jq to be installed.
    function addJsonKey(
        string memory pathInput,
        string memory pathOutput,
        string memory key
    ) internal returns (string memory fullInputData) {
        // Example: jq .abi=$data.abi --argfile data path/to/input.json path/to/output.json
        string[] memory inputs = new string[](6);
        inputs[0] = "jq";
        inputs[1] = key.concat(" = $data", key);
        inputs[2] = "--argfile";
        inputs[3] = "data";
        inputs[4] = pathInput;
        inputs[5] = pathOutput;
        return string(vm.ffi(inputs));
    }
}
