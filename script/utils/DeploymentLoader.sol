// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Base.sol";
import "forge-std/StdJson.sol";

contract DeploymentLoader is CommonBase {
    bytes1 private constant NEWLINE = bytes1("\n");
    bytes1 private constant ZERO = bytes1("0");
    bytes1 private constant NINE = bytes1("9");

    using stdJson for string;

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

    /// @notice Returns the deployment for a contract on a given chain, if it exists.
    function loadDeploymentAddress(string memory chain, string memory contractName)
        public
        view
        returns (address deployment)
    {
        string memory chainPath = _concat(_deploymentsPath(), chain, "/");
        string memory contractPath = _concat(chainPath, contractName, ".json");
        try vm.readFile(contractPath) returns (string memory json) {
            deployment = json.readAddress("address");
        } catch {
            // Doesn't exist
            deployment = address(0);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Returns the full path to the local deployment directory
    function _deploymentsPath() internal view returns (string memory) {
        return _concat(vm.projectRoot(), "/deployments/");
    }

    /// @dev Returns the chainId for the given chain
    /// Will return 0, if chainId is not saved in the deployments
    function _loadChainId(string memory chain) internal view returns (uint256 chainId) {
        string memory path = _concat(_deploymentsPath(), chain, "/.chainId");
        try vm.readLine(path) returns (string memory str) {
            chainId = _strToInt(str);
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
