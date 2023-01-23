// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {ScriptUtils} from "./ScriptUtils.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployerUtils is ScriptUtils, Script {
    using stdJson for string;

    /// @dev Name of the chain we are deploying onto
    string internal chain;
    /// @dev Whether the script will be broadcasted or not
    bool internal isBroadcasted = false;
    /// @dev Private key and address for deploying contracts
    uint256 internal broadcasterPK;
    address internal broadcasterAddress;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                SETUP                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function stopBroadcast() public {
        vm.stopBroadcast();
        isBroadcasted = false;
    }

    function startBroadcast(bool _isBroadcasted) public {
        vm.startBroadcast(broadcasterPK);
        isBroadcasted = _isBroadcasted;
    }

    function setupDeployerPK() public {
        setupPK("DEPLOYER_PRIVATE_KEY");
    }

    function setupPK(string memory pkEnvKey) public {
        broadcasterPK = vm.envUint(pkEnvKey);
        broadcasterAddress = vm.addr(broadcasterPK);
        console.log("Deployer address: %s", broadcasterAddress);
    }

    function setupChain(string memory _chain) public {
        require(bytes(_chain).length != 0, "Empty chain name");
        chain = _chain;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            DEPLOY CONFIG                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Checks if deploy config exists for a given contract on a given chain.
    function deployConfigExists(string memory contractName) public returns (bool) {
        try vm.fsMetadata(_deployConfigPath(contractName)) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Loads deploy config for a given contract on a given chain.
    /// Will revert if config doesn't exist.
    function loadDeployConfig(string memory contractName) public view returns (string memory json) {
        return vm.readFile(_deployConfigPath(contractName));
    }

    /// @notice Saves deploy config for a given contract on a given chain.
    function saveDeployConfig(string memory contractName, string memory config) public {
        console.log("Saved: config for [%s] on [%s]", contractName, chain);
        string memory path = _deployConfigPath(contractName);
        vm.writeJson(config, path);
        // Sort keys in config JSON for consistency
        sortJSON(path);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             DEPLOYMENTS                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns the deployment for a contract on a given chain, if it exists.
    /// Reverts if it doesn't exist.
    function loadDeployment(string memory contractName) public view returns (address deployment) {
        deployment = tryLoadDeployment(contractName);
        require(deployment != address(0), _concat(contractName, " doesn't exist on ", chain));
    }

    /// @notice Returns the deployment for a contract on a given chain, if it exists.
    /// Returns address(0), if it doesn't exist.
    function tryLoadDeployment(string memory contractName) public view returns (address deployment) {
        try vm.readFile(_deploymentPath(contractName)) returns (string memory json) {
            // We assume that if a deployment file exists, the contract is indeed deployed
            deployment = json.readAddress("address");
        } catch {
            // Doesn't exist
            deployment = address(0);
        }
    }

    /// @notice Saves the deployment JSON for a deployed contract.
    function saveDeployment(string memory contractName, address deployedAt) public {
        console.log("Deployed: [%s] on [%s] at %s", contractName, chain, deployedAt);
        // Do nothing if script isn't broadcasted
        if (!isBroadcasted) return;
        // Otherwise, save the deployment JSON
        string memory deployment = "deployment";
        // First, write only the deployment address
        deployment = deployment.serialize("address", deployedAt);
        deployment.write(_deploymentPath(contractName));
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ARTIFACTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the full artifact for a contract.
    function loadArtifact(string memory contractName) public view returns (string memory json) {
        return vm.readFile(_artifactPath(contractName));
    }

    /// @dev Returns the bytecode for a contract.
    function loadBytecode(string memory contractName) public view returns (bytes memory bytecode) {
        return loadArtifact(contractName).readBytes("bytecode.object");
    }

    /// @dev Reads JSON from given path, sorts its keys and overwrites the file.
    function sortJSON(string memory path) public {
        string[] memory inputs = new string[](4);
        inputs[0] = "jq";
        // sort keys of objects on output
        inputs[1] = "-S";
        // The simplest filter is ., which copies jq's input to its output unmodified
        inputs[2] = ".";
        inputs[3] = path;
        bytes memory sorted = vm.ffi(inputs);
        string(sorted).write(path);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the full path to the local deploy configs directory.
    function _artifactsPath() internal view returns (string memory path) {
        return _concat(vm.projectRoot(), "/artifacts/");
    }

    function _artifactPath(string memory contractName) internal view returns (string memory path) {
        return _concat(_artifactsPath(), contractName, ".sol/", contractName, ".json");
    }

    /// @dev Returns the full path to the local deployment directory.
    function _deploymentsPath() internal view returns (string memory path) {
        return _concat(vm.projectRoot(), "/deployments/");
    }

    /// @dev Returns the full path to the contract deployment JSON.
    function _deploymentPath(string memory contractName) internal view returns (string memory path) {
        return _concat(_deploymentsPath(), chain, "/", contractName, ".json");
    }

    /// @dev Returns the full path to the local deploy configs directory.
    function _deployConfigsPath() internal view returns (string memory path) {
        return _concat(vm.projectRoot(), "/script/configs/");
    }

    /// @dev Returns the full path to the contract deploy config JSON.
    function _deployConfigPath(string memory contractName) internal view returns (string memory path) {
        return _concat(_deployConfigsPath(), chain, "/", contractName, ".dc.json");
    }
}
