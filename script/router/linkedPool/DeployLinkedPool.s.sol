// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployLinkedPool is BasicSynapseScript {
    using StringUtils for string;
    using stdJson for string;

    string public constant LINKED_POOL = "LinkedPool";

    string public config;

    function run(string memory bridgeSymbol) external {
        // Setup the BasicSynapseScript
        setUp();
        string memory linkedPoolName = LINKED_POOL.concat(".", bridgeSymbol);
        config = getDeployConfig(linkedPoolName);
        vm.startBroadcast();
        deployAndSaveAs({contractName: LINKED_POOL, contractAlias: linkedPoolName, deployContract: deployLinkedPool});
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the LinkedPool contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployLinkedPool() internal returns (address deployedAt, bytes memory constructorArgs) {
        address bridgeToken = config.readAddress(".bridgeToken");
        address owner = vm.envAddress("OWNER_ADDR");
        deployedAt = address(new LinkedPool(bridgeToken, owner));
        constructorArgs = abi.encode(bridgeToken, owner);
    }
}
