// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20, MiniChefV2} from "../../../contracts/bridge/MiniChefV2.sol";

import {BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";
import {stdJson} from "forge-std/Script.sol";

contract DeployMiniChefV2 is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;

    string public constant MINI_CHEF_V2 = "MiniChefV2";
    address public rewardToken;

    function run(string memory rewardTokenName) external {
        // Setup the BasicSynapseScript
        setUp();
        loadConfig(rewardTokenName);
        vm.startBroadcast();
        // Deploy the MiniChefV2 contract
        deployAndSaveAs({
            contractName: MINI_CHEF_V2,
            contractAlias: MINI_CHEF_V2.concat(".", rewardTokenName),
            deployContract: deployMiniChefV2
        });
        vm.stopBroadcast();
    }

    function loadConfig(string memory rewardTokenName) internal {
        string memory config = getDeployConfig({contractName: MINI_CHEF_V2});
        string memory key = ".rewardTokens.";
        rewardToken = config.readAddress(key.concat(rewardTokenName));
    }

    /// @notice Callback function to deploy the MiniChefV2 contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployMiniChefV2() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new MiniChefV2(IERC20(rewardToken)));
        constructorArgs = abi.encode(rewardToken);
    }
}
