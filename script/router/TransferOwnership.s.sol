// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IOwnable} from "../interfaces/IOwnable.sol";

import {BasicRouterScript} from "./BasicRouter.s.sol";
import {console2} from "forge-std/Script.sol";

// solhint-disable no-console
contract TransferOwnership is BasicRouterScript {
    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        uint256 txAmount = transferOwnership(ROUTER_V1);
        txAmount += transferOwnership(ROUTER_V2);
        txAmount += transferOwnership(QUOTER_V1);
        txAmount += transferOwnership(QUOTER_V2);
        console2.log("Transferred ownership of %s contracts", txAmount);
        vm.stopBroadcast();
    }

    function transferOwnership(string memory contractName) internal returns (uint256 txAmount) {
        address contractAddress = tryGetDeploymentAddress(contractName);
        printLog(contractName);
        increaseIndent();
        if (contractAddress == address(0)) {
            printLog("Skipping: contract not deployed");
            decreaseIndent();
            return 0;
        }
        address curOwner = IOwnable(contractAddress).owner();
        if (curOwner != msg.sender) {
            printLog("Skipping: sender is not the owner");
            increaseIndent();
            printLog("sender: %s", msg.sender);
            printLog(" owner: %s", curOwner);
            decreaseIndent();
            decreaseIndent();
            return 0;
        }
        address newOwner = vm.envAddress("OWNER_ADDR");
        require(newOwner != address(0), "OWNER_ADDR not set");
        if (newOwner == msg.sender) {
            printLog("Skipping: new owner is the same as the sender");
            decreaseIndent();
            return 0;
        }
        printLog("Transferring ownership to: %s", newOwner);
        IOwnable(contractAddress).transferOwnership(newOwner);
        decreaseIndent();
        return 1;
    }
}
