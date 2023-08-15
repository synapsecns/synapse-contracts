// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract ConfigureLinkedPool is BasicSynapseScript {
    using StringUtils for string;
    using StringUtils for uint256;
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
        linkedPool = LinkedPool(getDeploymentAddress(linkedPoolName));
        vm.startBroadcast();
        configureLinkedPool();
        vm.stopBroadcast();
    }

    /// @dev Configures the LinkedPool by attaching pools to nodes.
    /// Skips pools that are already attached.
    function configureLinkedPool() internal {
        printLog("Configuring LinkedPool at %s", address(linkedPool));
        increaseIndent();
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            PoolParams memory params = poolParamsList[i];
            // TODO: add options to update pool module here on in a separate script?
            address poolModule = bytes(params.poolModule).length == 0
                ? address(0)
                : getDeploymentAddress(params.poolModule.concat("Module"));
            string memory module = poolModule == address(0) ? "None" : params.poolModule;
            if (isAttached(params.nodeIndex, params.pool)) {
                printLog(
                    StringUtils.concat(
                        "Skipping: already attached [node = ",
                        params.nodeIndex.fromUint(),
                        "] [pool = %s] [module = ",
                        module,
                        "]"
                    ),
                    params.pool
                );
            } else {
                printLog(
                    StringUtils.concat(
                        "Attaching: [node = ",
                        params.nodeIndex.fromUint(),
                        "] [pool = %s] [module = ",
                        module,
                        "]"
                    ),
                    params.pool,
                    poolModule
                );
                linkedPool.addPool(params.nodeIndex, params.pool, poolModule);
            }
        }
        decreaseIndent();
    }

    /// @dev Checks if a pool is already attached to a given node.
    function isAttached(uint256 nodeIndex, address pool) internal view returns (bool) {
        address[] memory attachedPools = linkedPool.getAttachedPools(uint8(nodeIndex));
        for (uint256 i = 0; i < attachedPools.length; ++i) {
            if (attachedPools[i] == pool) {
                return true;
            }
        }
        return false;
    }
}
