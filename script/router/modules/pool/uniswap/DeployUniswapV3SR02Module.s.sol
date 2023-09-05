// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {UniswapV3SR02Module} from "../../../../../contracts/router/modules/pool/uniswap/UniswapV3SR02Module.sol";

import {BasicSynapseScript} from "../../../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployUniswapV3SR02Module is BasicSynapseScript {
    using stdJson for string;

    string public constant UNI_V3_SR02_MODULE = "UniswapV3SR02Module";

    address public swapRouter02;
    address public staticQuoter;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        readConfig();
        // Use `deployUniswapV3SR02Module` as callback to deploy the contract
        address module = deployAndSave({contractName: UNI_V3_SR02_MODULE, deployContract: deployUniswapV3SR02Module});
        vm.stopBroadcast();
        // Verify the module was deployed correctly
        require(address(UniswapV3SR02Module(module).uniswapV3SwapRouter02()) == swapRouter02, "!swapRouter02");
        require(address(UniswapV3SR02Module(module).uniswapV3StaticQuoter()) == staticQuoter, "!staticQuoter");
    }

    function readConfig() internal {
        string memory config = getDeployConfig(UNI_V3_SR02_MODULE);
        swapRouter02 = config.readAddress(".uniswapV3SwapRouter02");
        staticQuoter = config.readAddress(".uniswapV3StaticQuoter");
    }

    /// @notice Callback function to deploy the UniswapV3SR02Module contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployUniswapV3SR02Module() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new UniswapV3SR02Module(swapRouter02, staticQuoter));
        constructorArgs = abi.encode(swapRouter02, staticQuoter);
    }
}
