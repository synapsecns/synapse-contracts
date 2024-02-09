// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseRouter} from "../interfaces/ISynapseRouter.sol";
import {BasicRouterScript} from "./BasicRouter.s.sol";

// solhint-disable no-console
contract ActivateRouterV1sQuoter is BasicRouterScript {
    function run(string memory quoterName) external {
        // Setup the BasicSynapseScript
        setUp();
        address router = getDeploymentAddress(ROUTER_V1);
        address quoter = getDeploymentAddress(quoterName);
        // Check if the quoter is already set
        if (ISynapseRouter(router).swapQuoter() == quoter) {
            printLog("Quoter already set");
            return;
        }
        // Check ownership of the SynapseRouter
        if (!checkOwner(router)) return;
        // Set the quoter
        printLog("%s: setting quoter to %s", router, quoter);
        vm.startBroadcast();
        ISynapseRouter(router).setSwapQuoter(quoter);
        vm.stopBroadcast();
    }
}
