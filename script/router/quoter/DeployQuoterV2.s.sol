// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";

import {BasicRouterScript} from "../BasicRouter.s.sol";

// solhint-disable no-console
/// @notice This script deploys the SwapQuoterV2 contract, without any configuration.
/// Use ConfigureQuoterV2.s.sol to configure the contract after deployment.
/// Note: ownership will be transferred to the "owner wallet" address read from .env file.
contract DeployQuoterV2 is BasicRouterScript {
    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployQuoterV2` as callback to deploy the contract
        deployAndSave({contractName: QUOTER_V2, deployContract: deployQuoterV2});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the SwapQuoterV2 contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployQuoterV2() internal returns (address deployedAt, bytes memory constructorArgs) {
        address synapseRouter = tryGetLatestRouterDeployment();
        address defaultPoolCalc = getDeploymentAddress(DEFAULT_POOL_CALC);
        // We need specifically WGAS, so that on BNB chain we use WBNB
        address weth = getDeploymentAddress("WGAS");
        // Read the owner address from .env
        address owner = vm.envAddress("OWNER_ADDR");
        deployedAt = address(new SwapQuoterV2(synapseRouter, defaultPoolCalc, weth, owner));
        constructorArgs = abi.encode(synapseRouter, defaultPoolCalc, weth, owner);
    }
}
