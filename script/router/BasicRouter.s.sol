// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

/// @notice Common tools for Router-related scripts.
abstract contract BasicRouterScript is BasicSynapseScript {
    string public constant DEFAULT_POOL_CALC = "DefaultPoolCalc";

    string public constant ROUTER_V1 = "SynapseRouter";
    string public constant ROUTER_V2 = "SynapseRouterV2";

    string public constant QUOTER_V1 = "SwapQuoter";
    string public constant QUOTER_V2 = "SwapQuoterV2";

    /// @notice Returns deployment of the latest SynapseRouter contract on the active chain.
    function getLatestRouterDeployment() internal returns (address synapseRouter) {
        // Check if SynapseRouterV2 is deployed
        synapseRouter = tryGetDeploymentAddress(ROUTER_V2);
        // Use SynapseRouter if SynapseRouterV2 is not deployed
        if (synapseRouter == address(0)) {
            synapseRouter = getDeploymentAddress(ROUTER_V1);
        }
    }

    /// @notice Returns deployment of the latest SynapseRouter contract on the active chain, if available.
    /// Otherwise, returns address(0).
    function tryGetLatestRouterDeployment() internal returns (address synapseRouter) {
        // Check if SynapseRouterV2 is deployed
        synapseRouter = tryGetDeploymentAddress(ROUTER_V2);
        // Use SynapseRouter if SynapseRouterV2 is not deployed
        if (synapseRouter == address(0)) {
            synapseRouter = tryGetDeploymentAddress(ROUTER_V1);
        }
    }
}
