// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import "@openzeppelin/contracts/utils/Address.sol";

contract BaseScript is Script {
    using Address for address;

    bytes1 private constant NEWLINE = bytes1("\n");
    bytes1 private constant ZERO = bytes1("0");
    bytes1 private constant NINE = bytes1("9");

    using stdJson for string;

    uint256 internal broadcasterPK;

    constructor() public {
        setUp();
    }

    /// @notice Sets up the common vars for the deploy script
    function setUp() public virtual {
        broadcasterPK = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    /// @notice Loads chain name with matching chainId from the local deployments.
    /// @dev Will revert if current chainid is not saved.
    function loadChainName(uint256 chainId) public returns (string memory chain) {
        require(chainId != 0, "Incorrect chainId");
        (bytes[] memory chains, uint256[] memory chainIds) = loadChains();
        for (uint256 i = 0; i < chainIds.length; ++i) {
            if (chainIds[i] == chainId) {
                require(bytes(chain).length == 0, "Multiple matching chains found");
                chain = string(chains[i]);
                // To make sure there's only one matching chain we don't return chain right away,
                // instead we check every chain in "./deployments"
            }
        }
        // Check that we found anything
        require(bytes(chain).length != 0, "No matching chains found");
    }

    /// @notice Loads all chains from the local deployments, alongside with their chainId.
    /// If chainId is not saved, the default zero value will be returned
    function loadChains() public returns (bytes[] memory chains, uint256[] memory chainIds) {
        string[] memory inputs = new string[](2);
        inputs[0] = "ls";
        inputs[1] = _deploymentsPath();
        bytes memory res = vm.ffi(inputs);
        chains = _splitString(abi.encodePacked(res, NEWLINE));
        uint256 amount = chains.length;
        chainIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            chainIds[i] = _loadChainId(string(chains[i]));
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              DEPLOYMENT                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Returns the deployment for a contract on a given chain, if it exists.
    /// Reverts if it doesn't exist.
    function loadDeployment(string memory chain, string memory contractName) public view returns (address deployment) {
        deployment = tryLoadDeployment(chain, contractName);
        require(deployment != address(0), _concat(contractName, " doesn't exist on ", chain));
    }

    /// @notice Returns the deployment for a contract on a given chain, if it exists.
    /// Returns address(0), if it doesn't exist.
    function tryLoadDeployment(string memory chain, string memory contractName)
        public
        view
        returns (address deployment)
    {
        try vm.readFile(_deploymentPath(chain, contractName)) returns (string memory json) {
            // We assume that if a deployment file exists, the contract is indeed deployed
            deployment = json.readAddress("address");
        } catch {
            // Doesn't exist
            deployment = address(0);
        }
    }

    /// @notice Saves the deployment JSON for a deployed contract.
    function saveDeployment(
        string memory chain,
        string memory contractName,
        address deployedAt
    ) public {
        console.log("Deployed: [%s] on [%s] at %s", contractName, chain, deployedAt);
        string memory deployment = "deployment";
        // First, write only the deployment address
        deployment = deployment.serialize("address", deployedAt);
        deployment.write(_deploymentPath(chain, contractName));
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
        inputs[5] = _deploymentPath(chain, contractName);
        bytes memory full = vm.ffi(inputs);
        // Finally, print the updated deployment JSON
        string(full).write(_deploymentPath(chain, contractName));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            DEPLOY CONFIG                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Checks if deploy config exists for a given contract on a given chain.
    function deployConfigExists(string memory chain, string memory contractName) public returns (bool) {
        try vm.fsMetadata(_deployConfigPath(chain, contractName)) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Loads deploy config for a given contract on a given chain.
    /// Will revert if config doesn't exist.
    function loadDeployConfig(string memory chain, string memory contractName)
        public
        view
        returns (string memory json)
    {
        json = vm.readFile(_deployConfigPath(chain, contractName));
    }

    /// @notice Saves deploy config for a given contract on a given chain.
    function saveDeployConfig(
        string memory chain,
        string memory contractName,
        string memory config
    ) public {
        console.log("Saved: config for [%s] on [%s]", contractName, chain);
        vm.writeJson(config, _deployConfigPath(chain, contractName));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the full path to the local deploy configs directory
    function _artifactsPath() internal view returns (string memory) {
        return _concat(vm.projectRoot(), "/artifacts/");
    }

    function _artifactPath(string memory contractName) internal view returns (string memory) {
        string memory contractPath = _concat(_artifactsPath(), contractName, ".sol/");
        return _concat(contractPath, contractName, ".json");
    }

    /// @dev Returns the full path to the local deploy configs directory
    function _deployConfigsPath() internal view returns (string memory) {
        return _concat(vm.projectRoot(), "/script/configs/");
    }

    /// @dev Returns the full path to the contract deploy config JSON
    function _deployConfigPath(string memory chain, string memory contractName) internal view returns (string memory) {
        string memory chainPath = _concat(_deployConfigsPath(), chain, "/");
        return _concat(chainPath, contractName, ".dc.json");
    }

    /// @dev Returns the full path to the local deployment directory
    function _deploymentsPath() internal view returns (string memory) {
        return _concat(vm.projectRoot(), "/deployments/");
    }

    /// @dev Returns the full path to the contract deployment JSON
    function _deploymentPath(string memory chain, string memory contractName) internal view returns (string memory) {
        string memory chainPath = _concat(_deploymentsPath(), chain, "/");
        return _concat(chainPath, contractName, ".json");
    }

    /// @dev Wrapper for block.chainid, which is not directly accessible in 0.6.12
    function _chainId() internal pure returns (uint256 chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
    }

    /// @dev Returns the chainId for the given chain
    /// Will return 0, if chainId is not saved in the deployments
    function _loadChainId(string memory chain) internal returns (uint256 chainId) {
        string memory path = _concat(_deploymentsPath(), chain, "/.chainId");
        try vm.readLine(path) returns (string memory str) {
            chainId = _strToInt(str);
            vm.closeFile(path);
        } catch {
            // Return 0 if .chainId doesn't exist
            chainId = 0;
        }
    }

    /// @dev Shortcut for concatenation of two strings.
    function _concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /// @dev Shortcut for concatenation of three strings.
    function _concat(
        string memory a,
        string memory b,
        string memory c
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    /// @dev Splits string having newlines as the separators. Should end with NEWLINE as well.
    function _splitString(bytes memory bStr) internal pure returns (bytes[] memory res) {
        uint256 found = 0;
        for (uint256 i = 0; i < bStr.length; ++i) {
            if (bStr[i] == NEWLINE) {
                ++found;
            }
        }
        res = new bytes[](found);
        found = 0;
        uint256 start = 0;
        while (start < bStr.length) {
            uint256 end = start;
            while (bStr[end] != NEWLINE) ++end;
            // [start, end)
            res[found] = new bytes(end - start);
            for (uint256 i = start; i < end; ++i) {
                res[found][i - start] = bStr[i];
            }
            ++found;
            start = end + 1;
        }
    }

    /// @dev Derives integer from its string representation.
    function _strToInt(string memory str) internal pure returns (uint256 val) {
        bytes memory bStr = bytes(str);
        for (uint256 i = 0; i < bStr.length; ++i) {
            bytes1 b = bStr[i];
            require(b >= ZERO && b <= NINE, "Not a digit");
            val = val * 10 + uint8(b) - uint8(ZERO);
        }
    }
}
