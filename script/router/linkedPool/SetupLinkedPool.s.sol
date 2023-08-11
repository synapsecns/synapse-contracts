// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {console2, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract SetupLinkedPool is BasicSynapseScript {
    using StringUtils for string;
    using stdJson for string;

    // enforce alphabetical order to match the JSON order
    struct PoolParams {
        uint256 nodeIndex;
        address pool;
        string poolModule;
    }

    string public constant LINKED_POOL = "LinkedPool";

    string public config;

    LinkedPool public linkedPool;

    function run(string memory bridgeSymbol) external {
        // Setup the BasicSynapseScript
        setUp();
        string memory linkedPoolName = LINKED_POOL.concat(".", bridgeSymbol);
        config = getDeployConfig(linkedPoolName);
        vm.startBroadcast();
        // First, deploy LinkedPool if it doesn't exist. If it does, this function will return the existing deployment
        linkedPool = LinkedPool(
            deployAndSaveAs({
                contractName: LINKED_POOL,
                contractAlias: linkedPoolName,
                deployContract: deployLinkedPool
            })
        );
        // Then, setup the LinkedPool
        setupLinkedPool();
        vm.stopBroadcast();
    }

    /// @notice Callback function to deploy the LinkedPool contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployLinkedPool() internal returns (address deployedAt, bytes memory constructorArgs) {
        address bridgeToken = config.readAddress(".bridgeToken");
        deployedAt = address(new LinkedPool(bridgeToken));
        constructorArgs = abi.encode(bridgeToken);
    }

    function setupLinkedPool() internal {
        // TODO: take into account the existing pools
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            PoolParams memory params = poolParamsList[i];
            address poolModule = bytes(params.poolModule).length == 0
                ? address(0)
                : getDeploymentAddress(params.poolModule.concat("Module"));
            linkedPool.addPool(params.nodeIndex, params.pool, poolModule);
        }
        console2.log("Total amount of nodes: %s", linkedPool.tokenNodesAmount());
    }
}
