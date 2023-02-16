// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./DeployRouter.s.sol";

contract DeployFactoryRouterScript is DeployRouterScript {
    bytes32 internal constant ROUTER_DEFAULT_SALT = "Router";
    bytes32 internal constant QUOTER_DEFAULT_SALT = "Quoter";

    bytes32 internal routerSalt;
    bytes32 internal quoterSalt;

    constructor() public {
        setupFactory();
        // TODO: setup (mined) salts for vanity deployments in .env?
        routerSalt = loadDeploySalt(ROUTER, "ROUTER_SALT", ROUTER_DEFAULT_SALT);
        quoterSalt = loadDeploySalt(QUOTER, "QUOTER_SALT", QUOTER_DEFAULT_SALT);
    }

    /// @dev Deploys SynapseRouter. Function is virtual to allow different deploy workflows.
    function _deployRouter(address bridge) internal virtual override {
        // abi encode constructor arguments: (bridge, owner)
        bytes memory constructorArgs = abi.encode(bridge, broadcasterAddress);
        // Deploy SynapseRouter and save it to the deployments. No initializer call is required.
        address deployment = deploy(ROUTER, routerSalt, constructorArgs, bytes(""));
        router = SynapseRouter(payable(deployment));
    }

    /// @dev Deploys SwapQuoter. Function is virtual to allow different deploy workflows.
    function _deployQuoter(address wgas) internal virtual override {
        // abi encode constructor arguments: (router, wgas, owner)
        bytes memory constructorArgs = abi.encode(router, wgas, broadcasterAddress);
        // Deploy SwapQuoter and save it to the deployments. No initializer call is required.
        address deployment = deploy(QUOTER, quoterSalt, constructorArgs, bytes(""));
        quoter = SwapQuoter(deployment);
    }
}
