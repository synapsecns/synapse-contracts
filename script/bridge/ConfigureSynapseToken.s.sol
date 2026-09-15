// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseERC20} from "../../contracts/bridge/SynapseERC20.sol";
import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract ConfigureSynapseToken is BasicSynapseScript {
    /// @notice Grants minting permissions to the active chain's SynapseAdapter deployment.
    function run() external {
        setUp();
        SynapseERC20 token = SynapseERC20(getDeploymentAddress("SynapseToken"));
        if (!token.hasRole(token.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            printLog("Skipping: sender is not an admin");
            return;
        }
        address synapseAdapter = getDeploymentAddress("SynapseAdapter");
        bytes32 minterRole = token.MINTER_ROLE();

        vm.startBroadcast(msg.sender);
        if (!token.hasRole(minterRole, synapseAdapter)) {
            token.grantRole(minterRole, synapseAdapter);
            printLog("Granted MINTER_ROLE to SynapseAdapter: %s", synapseAdapter);
        } else {
            printLog("Skipping: SynapseAdapter is already a minter: %s", synapseAdapter);
        }
        vm.stopBroadcast();

        require(token.hasRole(minterRole, synapseAdapter), "SynapseAdapter is not a minter");
    }
}
