// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {console2, BasicSynapseScript} from "../../templates/BasicSynapse.s.sol";

// solhint-disable no-console
contract DeployDefaultPoolCalc is BasicSynapseScript {
    string public constant DEFAULT_POOL_CALC = "DefaultPoolCalc";

    bytes32 public constant DEFAULT_POOL_SALT = 0x00000000000000000000000000000000000000005d5671278eda4e032fc2a223;

    function run() external {
        setUp();
        // Print init code hash for salt mining
        console2.logBytes32(keccak256(type(DefaultPoolCalc).creationCode));
        vm.startBroadcast();
        setDeploymentSalt(DEFAULT_POOL_SALT);
        deployAndSave({contractName: DEFAULT_POOL_CALC, constructorArgs: "", deployFn: deployCreate2});
        vm.stopBroadcast();
    }
}
