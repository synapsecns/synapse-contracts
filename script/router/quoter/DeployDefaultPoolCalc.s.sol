// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {console2, BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
/// @notice This script deploys the DefaultPoolCalc contract in a deterministic way
/// using CREATE2 via `IMMUTABLE_CREATE2_FACTORY`.
contract DeployDefaultPoolCalc is BasicSynapseScript {
    using StringUtils for string;
    using stdJson for string;

    // Order of the struct members must match the alphabetical order of the JSON keys
    struct SaltEntry {
        bytes32 initCodeHash;
        address predictedAddress;
        bytes32 salt;
    }

    string public constant DEFAULT_POOL_CALC = "DefaultPoolCalc";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        // Get the salt for the deployment associated with the given init code hash
        bytes32 initCodeHash = keccak256(type(DefaultPoolCalc).creationCode);
        string memory saltsJson = getGlobalDeployConfig(DEFAULT_POOL_CALC.concat(".salts"));
        SaltEntry[] memory salts = abi.decode(saltsJson.parseRaw(".entries"), (SaltEntry[]));
        bool found = false;
        address predictedAddress;
        for (uint256 i = 0; i < salts.length; ++i) {
            if (salts[i].initCodeHash == initCodeHash) {
                found = true;
                predictedAddress = salts[i].predictedAddress;
                setDeploymentSalt(salts[i].salt);
                break;
            }
        }
        if (!found) {
            console2.logBytes32(initCodeHash);
            revert("Salt not found");
        }
        vm.startBroadcast();
        // Use `deployCreate2` as callback to deploy the contract with CREATE2
        address deployedAt = deployAndSave({
            contractName: DEFAULT_POOL_CALC,
            constructorArgs: "",
            deployCode: deployCreate2
        });
        require(deployedAt == predictedAddress, "Predicted address incorrect");
        vm.stopBroadcast();
    }
}
