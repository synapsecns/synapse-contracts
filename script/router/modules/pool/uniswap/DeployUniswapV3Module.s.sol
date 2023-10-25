// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {UniswapV3Module} from "../../../../../contracts/router/modules/pool/uniswap/UniswapV3Module.sol";

import {BasicSynapseScript, StringUtils} from "../../../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployUniswapV3Module is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;

    string public constant UNI_V3_MODULE = "UniswapV3Module";

    address public uniswapV3Router;
    address public staticQuoter;

    function run(string memory uniswapForkName) external {
        string memory key = string.concat(".", uniswapForkName);
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        readConfig(key);
        // Use `deployUniswapV3Module` as callback to deploy the contract
        address module = deployAndSaveAs({
            contractName: UNI_V3_MODULE,
            contractAlias: UNI_V3_MODULE.concat(key),
            deployContract: deployUniswapV3Module
        });
        vm.stopBroadcast();
        // Verify the module was deployed correctly
        require(address(UniswapV3Module(module).uniswapV3Router()) == uniswapV3Router, "!uniswapV3Router");
        require(address(UniswapV3Module(module).uniswapV3StaticQuoter()) == staticQuoter, "!staticQuoter");
    }

    function readConfig(string memory key) internal {
        string memory config = getDeployConfig(UNI_V3_MODULE);
        uniswapV3Router = config.readAddress(key.concat(".uniswapV3Router"));
        staticQuoter = config.readAddress(key.concat(".uniswapV3StaticQuoter"));
    }

    /// @notice Callback function to deploy the UniswapV3Module contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployUniswapV3Module() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new UniswapV3Module(uniswapV3Router, staticQuoter));
        constructorArgs = abi.encode(uniswapV3Router, staticQuoter);
    }
}
