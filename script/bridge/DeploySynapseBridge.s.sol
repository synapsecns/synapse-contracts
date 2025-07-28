// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";

contract DeploySynapseBridge is BasicSynapseScript {
    using StringUtils for string;

    bytes32 internal salt = 0x60b37663118720d6c967cd1be94aa5218f2440a06e95254b16d80a5ed3224c4c;
    address internal predicted = 0x5B0000258c622551A1c7C45b9f860Ef90200005B;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        if (activeChain.equals("zkevm")) {
            printLog("🟡 Skipping: zkevm doesn't have an active deployment");
            return;
        }
        address bridge = tryGetDeploymentAddress("SynapseBridge");
        if (bridge == address(0)) {
            printLog(StringUtils.concat("🟡 Skipping: SynapseBridge is not deployed on ", activeChain));
            return;
        }
        vm.startBroadcast();
        printLog(StringUtils.concat("Predicted address: ", vm.toString(predicted)));
        setDeploymentSalt(salt);
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
