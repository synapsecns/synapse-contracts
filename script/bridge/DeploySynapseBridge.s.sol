// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseBridge} from "../../contracts/bridge/SynapseBridge.sol";

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";

contract DeploySynapseBridge is BasicSynapseScript {
    using StringUtils for string;

    // TODO: mine a create2 salt for this
    bytes32 internal salt = 0;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        address predicted = predictAddress(type(SynapseBridge).creationCode, salt);
        printLog(StringUtils.concat("Predicted address: ", vm.toString(predicted)));
        address deployed = deployAndSaveAs({
            contractName: "SynapseBridge",
            contractAlias: "SynapseBridge.Implementation",
            constructorArgs: "",
            deployCode: deployCreate2
        });
        if (predicted != deployed) {
            printLog(TAB.concat("❌ Predicted address mismatch"));
            assert(false);
        }
        vm.stopBroadcast();
    }
}
