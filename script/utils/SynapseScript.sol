// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {ScriptUtils} from "./ScriptUtils.sol";

import {console, Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract SynapseScript is ScriptUtils, Script {
    using stdJson for string;

    string internal constant ARTIFACTS = "artifacts/";
    string internal constant FRESH_DEPLOYMENTS = ".deployments/";
    string internal constant DEPLOYMENTS = "deployments/";
    string internal constant DEPLOY_CONFIGS = "script/configs/";

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

    function setupPK(string memory pkEnvKey) public {
        broadcasterPK = vm.envUint(pkEnvKey);
        broadcasterAddress = vm.addr(broadcasterPK);
        console.log("Deployer address: %s", broadcasterAddress);
        console.log("Deployer balance: %s", _fromWei(broadcasterAddress.balance));
    }

    function setupChain(string memory _chain) public {
        require(bytes(_chain).length != 0, "Empty chain name");
        chain = _chain;
    }

    function loadAddress(string memory pkEnvKey) public view returns (address) {
        uint256 privKey = vm.envUint(pkEnvKey);
        return vm.addr(privKey);
    }

    /// @notice Loads chain name using block.chainid from the local deployments.
    /// @dev Will revert if current chainid is not saved.
    function loadChain() public {
        loadChain(_chainId());
    }

    /// @notice Loads chain name with matching chainId from the local deployments.
    /// @dev Will revert if chainid is not saved.
    function loadChain(uint256 chainId) public {
        require(chainId != 0, "Incorrect chainId");
        (bytes[] memory chains, uint256[] memory chainIds) = loadChains();
        string memory _chain = "";
        for (uint256 i = 0; i < chainIds.length; ++i) {
            if (chainIds[i] == chainId) {
                require(bytes(_chain).length == 0, "Multiple matching chains found");
                _chain = string(chains[i]);
                // To make sure there's only one matching chain we don't return chain right away,
                // instead we check every chain in "./deployments"
            }
        }
        setupChain(_chain);
    }

    /// @notice Loads all chains from the local deployments, alongside with their chainId.
    /// If chainId is not saved, the default zero value will be returned
    function loadChains() public returns (bytes[] memory chains, uint256[] memory chainIds) {
        string[] memory inputs = new string[](2);
        inputs[0] = "ls";
        inputs[1] = DEPLOYMENTS;
        bytes memory res = vm.ffi(inputs);
        chains = _splitString(abi.encodePacked(res, NEWLINE));
        uint256 amount = chains.length;
        chainIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            chainIds[i] = loadChainId(string(chains[i]));
        }
    }

    /// @notice Loads the chainId for the given chain from the local deployments
    function loadChainId(string memory _chain) public returns (uint256 chainId) {
        string memory path = _concat(DEPLOYMENTS, _chain, "/.chainId");
        try vm.readLine(path) returns (string memory str) {
            chainId = _strToInt(str);
            vm.closeFile(path);
        } catch {
            // Return 0 if .chainId doesn't exist
            chainId = 0;
        }
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
    function loadDeployment(string memory contractName) public returns (address deployment) {
        deployment = tryLoadDeployment(contractName);
        require(deployment != address(0), _concat(contractName, " doesn't exist on ", chain));
    }

    /// @notice Returns the deployment for a contract on a given chain, if it exists.
    /// Returns address(0), if it doesn't exist.
    function tryLoadDeployment(string memory contractName) public returns (address deployment) {
        try vm.readFile(_deploymentPath(contractName)) returns (string memory json) {
            // We assume that if a deployment file exists, the contract is indeed deployed
            deployment = json.readAddress(".address");
        } catch {
            // Doesn't exist
            deployment = address(0);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ARTIFACTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the full artifact for a contract.
    function loadArtifact(string memory contractName) public view returns (string memory json) {
        return vm.readFile(_artifactPath(contractName));
    }

    /// @dev Returns the bytecode for a contract.
    function loadBytecode(string memory contractName) public returns (bytes memory bytecode) {
        return loadArtifact(contractName).readBytes(".bytecode.object");
    }

    /// @dev Returns "manually generated" bytecode for a contract.
    function loadGeneratedBytecode(string memory contractName) public returns (bytes memory bytecode) {
        string memory path = _concat("script/bytecode/", contractName, ".json");
        return vm.readFile(path).readBytes(".bytecode");
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

    function _artifactPath(string memory contractName) internal pure returns (string memory path) {
        return _concat(ARTIFACTS, contractName, ".sol/", contractName, ".json");
    }

    /// @dev Returns the full path to the FRESH contract deployment JSON, which is
    /// optimistically saved by the deploy script regardless of whether the deployment went fine.
    function _freshDeploymentPath(string memory contractName) internal view returns (string memory path) {
        return _concat(FRESH_DEPLOYMENTS, chain, "/", contractName, ".json");
    }

    /// @dev Returns the full path to the contract deployment JSON.
    function _deploymentPath(string memory contractName) internal view returns (string memory path) {
        return _concat(DEPLOYMENTS, chain, "/", contractName, ".json");
    }

    /// @dev Returns the full path to the contract deploy config JSON.
    function _deployConfigPath(string memory contractName) internal view returns (string memory path) {
        return _concat(DEPLOY_CONFIGS, chain, "/", contractName, ".dc.json");
    }
}
