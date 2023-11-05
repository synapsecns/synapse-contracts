// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILinkedPool} from "../../../contracts/router/interfaces/ILinkedPool.sol";
import {BridgeToken} from "../../../contracts/router/libs/Structs.sol";
import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";
import {SynapseCCTP} from "../../../contracts/cctp/SynapseCCTP.sol";

import {BridgeConfigLens, IBridgeConfigV3} from "./helpers/BridgeConfigLens.sol";
import {console2, BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
/// @notice This script saves the config for the SwapQuoterV2 contract
/// by inspecting BridgeConfigV3 contract on Mainnet.
contract SaveConfigQuoterV2 is BasicSynapseScript, BridgeConfigLens {
    using StringUtils for *;
    using stdJson for string;

    string public constant MAINNET_RPC_ENV = "MAINNET_API";
    string public constant QUOTER_V2 = "SwapQuoterV2";
    uint256 public constant MAINNET_CHAIN_ID = 1;

    string public config;
    mapping(address => bool) public isIgnoredPool;

    SwapQuoterV2.BridgePool[] public savedPools;
    string[] public savedPoolSymbols;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        string memory configFN = deployConfigPath(QUOTER_V2);
        if (fileExists(configFN)) {
            console2.log("Skipping: deploy config for [%s] on [%s] already exists", QUOTER_V2, activeChain);
            config = getDeployConfig(QUOTER_V2);
            return;
        }
        // Get a list of pools that should be ignored by the quoter
        loadIgnoredPools();
        saveSynapseCCTPPools();
        saveBridgeConfigPools();
        // TODO: save origin-only pools as well
        // Serialize the config
        config = "config";
        config = config.serialize("pools", serializeSavedPools());
        config.write(configFN);
    }

    /// @notice Loads the list of pools that should be ignored by the Quoter
    function loadIgnoredPools() internal {
        string memory ignoredJson = getGlobalConfig(QUOTER_V2, "ignored");
        string[] memory ignoredContractNames = ignoredJson.readStringArray(".contractNames");
        // Add existing deployments to the ignored list
        for (uint256 i = 0; i < ignoredContractNames.length; ++i) {
            address ignoredPool = tryGetDeploymentAddress(ignoredContractNames[i]);
            if (ignoredPool != address(0)) {
                isIgnoredPool[ignoredPool] = true;
            }
        }
        // Add the zero address to the ignored list to simplify the logic
        isIgnoredPool[address(0)] = true;
    }

    /// @notice Saves pool to be later added to SwapQuoterV2 config
    function savePoolIfNotIgnored(
        address bridgeToken,
        address pool,
        string memory symbol
    ) internal {
        if (isIgnoredPool[pool]) return;
        savedPools.push(SwapQuoterV2.BridgePool({bridgeToken: bridgeToken, poolType: getPoolType(pool), pool: pool}));
        savedPoolSymbols.push(symbol);
    }

    /// @notice Saves the whitelisted bridge pools from the Mainnet BridgeConfigV3 contract in `savedPools`
    function saveBridgeConfigPools() internal {
        // Save current chainId, then switch to Mainnet
        uint256 forkId = vm.activeFork();
        uint256 chainId = blockChainId();
        // Switch to Mainnet if we're not already there
        if (chainId != MAINNET_CHAIN_ID) {
            string memory mainnetRPC = vm.envString(MAINNET_RPC_ENV);
            vm.createSelectFork(mainnetRPC);
        }
        // get the config for the current chain
        (
            string[] memory tokenIDs,
            IBridgeConfigV3.Token[] memory tokens,
            IBridgeConfigV3.Pool[] memory pools
        ) = getChainConfig(chainId);
        // Switch back to the original chain (if we switched)
        if (chainId != MAINNET_CHAIN_ID) vm.selectFork(forkId);
        for (uint256 i = 0; i < pools.length; ++i) {
            address pool = pools[i].poolAddress;
            savePoolIfNotIgnored({
                bridgeToken: stringToAddress(tokens[i].tokenAddress),
                pool: pool,
                symbol: tokenIDs[i]
            });
        }
    }

    /// @notice Saves the whitelisted pools for the SynapseCCTP bridge tokens in `savedPools`
    function saveSynapseCCTPPools() internal {
        address synapseCCTPDeployment = tryGetDeploymentAddress("SynapseCCTP");
        if (synapseCCTPDeployment == address(0)) {
            console2.log("Skipping: SynapseCCTP deployment not found on %s", activeChain);
            return;
        }
        SynapseCCTP synapseCCTP = SynapseCCTP(synapseCCTPDeployment);
        BridgeToken[] memory bridgeTokens = synapseCCTP.getBridgeTokens();
        // Iterate over whitelisted pools for the SynapseCCTP bridge tokens
        for (uint256 i = 0; i < bridgeTokens.length; ++i) {
            address pool = synapseCCTP.circleTokenPool(bridgeTokens[i].token);
            savePoolIfNotIgnored({bridgeToken: bridgeTokens[i].token, pool: pool, symbol: bridgeTokens[i].symbol});
        }
    }

    function serializeSavedPools() internal returns (string memory json) {
        json = "json.pools";
        for (uint256 i = 0; i < savedPools.length; ++i) {
            address pool = savedPools[i].pool;
            string memory jsonPool = "local";
            jsonPool.serialize("bridgeSymbol", savedPoolSymbols[i]);
            jsonPool.serialize("isLinked", savedPools[i].poolType == SwapQuoterV2.PoolType.Linked);
            jsonPool.serialize("pool", pool);
            jsonPool = jsonPool.serialize("token", savedPools[i].bridgeToken);
            // Use "0", "1", "2", ... as keys for the pools because
            // forge doesn't support serializing arrays of objects at the moment
            string memory key = i.fromUint();
            if (i == savedPools.length - 1) {
                json = json.serialize(key, jsonPool);
            } else {
                json.serialize(key, jsonPool);
            }
        }
    }

    function isLinkedPool(address pool) internal view returns (bool) {
        // Issue a static call to pool.tokenNodesAmount() which is only implemented by LinkedPool
        (bool success, ) = pool.staticcall(abi.encodeWithSelector(ILinkedPool.tokenNodesAmount.selector));
        return success;
    }

    function getPoolType(address pool) internal view returns (SwapQuoterV2.PoolType) {
        return isLinkedPool(pool) ? SwapQuoterV2.PoolType.Linked : SwapQuoterV2.PoolType.Default;
    }
}
