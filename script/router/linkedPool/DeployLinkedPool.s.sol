// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {DeployScript} from "../../utils/DeployScript.sol";

import {console, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract DeployLinkedPoolScript is DeployScript {
    using stdJson for string;

    // enforce alphabetical order to match the JSON order
    struct PoolParams {
        uint256 nodeIndex;
        address pool;
        string poolModule;
    }

    string public constant LINKED_POOL = "LinkedPool";

    string public config;
    string public linkedPoolName;

    LinkedPool public linkedPool;

    function execute(bool _isBroadcasted) public override {
        // Load deployer private key
        setupDeployerPK();
        // Load chain name that block.chainid refers to
        loadChain();
        loadConfig();
        startBroadcast(_isBroadcasted);
        deployLinkedPool();
        setupLinkedPool();
        stopBroadcast();
    }

    function loadConfig() internal {
        string memory bridgeSymbol = vm.envString("BRIDGE_SYMBOL");
        linkedPoolName = _concat(LINKED_POOL, ".", bridgeSymbol);
        config = loadDeployConfig(linkedPoolName);
    }

    function deployLinkedPool() internal {
        address bridgeToken = config.readAddress(".bridgeToken");
        linkedPool = new LinkedPool(bridgeToken);
        saveDeployment(linkedPoolName, address(linkedPool), abi.encode(bridgeToken));
    }

    function setupLinkedPool() internal {
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            PoolParams memory params = poolParamsList[i];
            address poolModule = bytes(params.poolModule).length == 0 ? address(0) : loadDeployment(params.poolModule);
            linkedPool.addPool(params.nodeIndex, params.pool, poolModule);
        }
        console.log("Total amount of nodes: %s", linkedPool.tokenNodesAmount());
    }
}
