// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";
import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract TransferSynapseTokenAdmin is BasicSynapseScript {
    function run() external {
        setUp();
        SynapseERC20 token = SynapseERC20(getDeploymentAddress("SynapseToken"));
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();
        if (!token.hasRole(adminRole, msg.sender)) {
            printLog("Skipping: sender is not an admin");
            return;
        }
        address multisig = getDeploymentAddress("DevMultisig");

        vm.startBroadcast(msg.sender);
        if (!token.hasRole(adminRole, multisig)) {
            token.grantRole(adminRole, multisig);
            printLog("Granted DEFAULT_ADMIN_ROLE to DevMultisig: %s", multisig);
        }
        if (msg.sender != multisig) {
            token.renounceRole(adminRole, msg.sender);
            printLog("Renounced DEFAULT_ADMIN_ROLE for sender: %s", msg.sender);
        }
        vm.stopBroadcast();

        require(token.hasRole(adminRole, multisig), "DevMultisig is not the admin");
        require(token.getRoleMemberCount(adminRole) == 1, "Admin count is not 1");
    }
}
