pragma solidity 0.8.17;
// SPDX-License-Identifier: MIT

import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";
import {console2, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract DeployCreate2Factory is BasicSynapseScript {
    using stdJson for string;

    string public constant CREATE2_FACTORY = "Create2Factory";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        address deployedAt = tryGetDeploymentAddress(CREATE2_FACTORY);
        if (deployedAt != address(0)) {
            console2.log("Skipping: Create2Factory already deployed at %s", deployedAt);
            return;
        }
        vm.startBroadcast();
        uint64 nonce = vm.getNonce(msg.sender);
        if (nonce != 0) {
            console2.log("Skipping: %s nonce is %s (not 0)", msg.sender, nonce);
        } else {
            deployedAt = deployFactory();
            verifyFactoryDeployment(deployedAt);
            saveFactoryDeployment(deployedAt);
        }
        vm.stopBroadcast();
    }

    function deployFactory() internal returns (address deployedAt) {
        string memory config = getGlobalConfig({contractName: CREATE2_FACTORY, globalProperty: "code"});
        bytes memory initCode = config.readBytes(".initCode");
        // Use assembly to deploy the factory contract
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Add 0x20 to skip the length field of initCode
            deployedAt := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployedAt != address(0), "Failed to deploy Create2Factory");
    }

    function verifyFactoryDeployment(address deployedAt) internal {
        string memory config = getGlobalConfig({contractName: CREATE2_FACTORY, globalProperty: "code"});
        bytes memory bytecode = config.readBytes(".bytecode");
        bytes memory deployedBytecode = deployedAt.code;
        // Should match the bytecode of the deployed contract
        if (keccak256(bytecode) != keccak256(deployedBytecode)) {
            console2.log("  Deployed bytecode");
            console2.logBytes(deployedBytecode);
            console2.log("  Expected bytecode");
            console2.logBytes(bytecode);
            revert("Bytecode does not match");
        }
    }

    function saveFactoryDeployment(address deployedAt) internal {
        console2.log("Deployed Create2Factory at %s", deployedAt);
        // Save minimal deployment artifact
        string memory data = serializeDeploymentData({deployedAt: deployedAt, constructorArgs: ""});
        data.write(freshDeploymentPath({contractName: CREATE2_FACTORY}));
    }
}
