// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicRouterScript} from "./BasicRouter.s.sol";
import {StringUtils} from "../templates/StringUtils.sol";

interface ISynapseRouterManagement {
    function bridgeTokens() external view returns (address[] memory tokens);

    function removeTokens(address[] calldata tokens) external;
}

// solhint-disable no-console
contract RemoveRouterTokens is BasicRouterScript {
    using StringUtils for uint256;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        address router = getDeploymentAddress(ROUTER_V1);
        address[] memory tokens = ISynapseRouterManagement(router).bridgeTokens();
        printLog("SynapseRouter: %s", router);
        printLog(StringUtils.concat("Found ", tokens.length.fromUint(), " bridge tokens"));
        if (tokens.length == 0) {
            return;
        }
        if (!checkOwner(router)) return;
        increaseIndent();
        for (uint256 i = 0; i < tokens.length; ++i) {
            printLog("Removing token: %s", tokens[i]);
        }
        vm.startBroadcast();
        ISynapseRouterManagement(router).removeTokens(tokens);
        vm.stopBroadcast();
        decreaseIndent();
    }
}
