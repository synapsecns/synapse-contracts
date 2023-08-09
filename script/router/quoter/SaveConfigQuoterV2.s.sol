// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILinkedPool} from "../../../contracts/router/interfaces/ILinkedPool.sol";

import {BridgeConfigLens, IBridgeConfigV3} from "./helpers/BridgeConfigLens.sol";
import {console2, BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
/// @notice This script saves the config for the SwapQuoterV2 contract
/// by inspecting BridgeConfigV3 contract on Mainnet.
contract SaveConfigQuoterV2 is BasicSynapseScript, BridgeConfigLens {
    using StringUtils for string;
    using stdJson for string;

    string public constant MAINNET_RPC_ENV = "MAINNET_API";
    string public constant QUOTER_V2 = "SwapQuoterV2";

    string public config;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        string memory configFN = deployConfigPath(QUOTER_V2);
        if (fileExists(configFN)) {
            console2.log("Skipping: deploy config for [%s] on [%s] already exists", QUOTER_V2, activeChain);
            config = getDeployConfig(QUOTER_V2);
            return;
        }
        // Save current chainId, then switch to Mainnet
        uint256 forkId = vm.activeFork();
        uint256 chainId = blockChainId();
        string memory mainnetRPC = vm.envString(MAINNET_RPC_ENV);
        vm.createSelectFork(mainnetRPC);
        // get the config for the current chain
        (
            string[] memory tokenIDs,
            IBridgeConfigV3.Token[] memory tokens,
            IBridgeConfigV3.Pool[] memory pools
        ) = getChainConfig(chainId);
        // Switch back to the original chain
        vm.selectFork(forkId);
        config = "config";
        serializePoolIDs(tokenIDs, pools);
        serializePools(tokenIDs, tokens, pools);
        // TODO: serialize origin-only pools as well
        config.write(configFN);
    }

    function serializePoolIDs(string[] memory tokenIDs, IBridgeConfigV3.Pool[] memory pools) internal {
        // Filter out pools that don't exist
        uint256 poolsLength = 0;
        for (uint256 i = 0; i < pools.length; ++i) {
            if (pools[i].poolAddress != address(0)) {
                ++poolsLength;
            }
        }
        string[] memory poolIDs = new string[](poolsLength);
        poolsLength = 0;
        for (uint256 i = 0; i < pools.length; ++i) {
            if (pools[i].poolAddress != address(0)) {
                console2.log("Token ID: %s", tokenIDs[i]);
                console2.log("Pool address: %s", pools[i].poolAddress);
                poolIDs[poolsLength++] = tokenIDs[i];
            }
        }
        config.serialize("ids", poolIDs);
    }

    function serializePools(
        string[] memory tokenIDs,
        IBridgeConfigV3.Token[] memory tokens,
        IBridgeConfigV3.Pool[] memory pools
    ) internal returns (string memory json) {
        // Find out how many pools exist
        uint256 poolsLength = 0;
        for (uint256 i = 0; i < pools.length; ++i) {
            if (pools[i].poolAddress != address(0)) {
                ++poolsLength;
            }
        }
        json = "json.pools";
        uint256 poolsFound = 0;
        for (uint256 i = 0; i < pools.length; ++i) {
            if (pools[i].poolAddress == address(0)) continue;
            ++poolsFound;
            string memory jsonPool = "local";
            jsonPool.serialize("isLinked", isLinkedPool(pools[i].poolAddress));
            jsonPool.serialize("pool", pools[i].poolAddress);
            jsonPool = jsonPool.serialize("token", stringToAddress(tokens[i].tokenAddress));
            if (poolsFound == poolsLength) {
                json = json.serialize(tokenIDs[i], jsonPool);
            } else {
                json.serialize(tokenIDs[i], jsonPool);
            }
        }
        config = config.serialize("pools", json);
    }

    function isLinkedPool(address pool) internal view returns (bool) {
        // Issue a static call to pool.tokenNodesAmount() which is only implemented by LinkedPool
        (bool success, ) = pool.staticcall(abi.encodeWithSelector(ILinkedPool.tokenNodesAmount.selector));
        return success;
    }
}
