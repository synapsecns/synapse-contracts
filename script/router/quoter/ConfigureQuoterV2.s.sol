// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";

import {BasicRouterScript} from "../BasicRouter.s.sol";
import {StringUtils} from "../../templates/StringUtils.sol";
import {console2, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
/// @notice This script configures the SwapQuoterV2 contract. It could be used
/// for initial setup after the deployment, or to update the configuration later.
/// Note: ensure you're running the script with the owner address as the broadcaster.
contract ConfigureQuoterV2 is BasicRouterScript {
    using StringUtils for string;
    using StringUtils for uint256;
    using stdJson for string;

    // Order of the struct members must match the alphabetical order of the JSON keys
    struct PoolEntry {
        string description;
        bool isLinked;
        address poolAddress;
        address tokenAddress;
    }

    SwapQuoterV2 public quoterV2;

    string public config;
    SwapQuoterV2.BridgePool[] public configBridgePools;
    mapping(address => string) public bridgeTokenToSymbol;
    mapping(string => address) public symbolToBridgeToken;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        quoterV2 = SwapQuoterV2(getDeploymentAddress(QUOTER_V2));
        // Check if sender is the owner
        if (!checkOwner(address(quoterV2))) return;
        readConfig();
        vm.startBroadcast();
        setSynapseRouter();
        setPools();
        vm.stopBroadcast();
    }

    function readConfig() internal {
        config = getDeployConfig(QUOTER_V2);
        string[] memory keys = vm.parseJsonKeys(config, ".pools");
        for (uint256 i = 0; i < keys.length; ++i) {
            string memory key = StringUtils.concat(".pools.", keys[i]);
            PoolEntry memory pool = abi.decode(config.parseRaw(key), (PoolEntry));
            configBridgePools.push(
                SwapQuoterV2.BridgePool({
                    bridgeToken: pool.tokenAddress,
                    poolType: pool.isLinked ? SwapQuoterV2.PoolType.Linked : SwapQuoterV2.PoolType.Default,
                    pool: pool.poolAddress
                })
            );
            // Origin-only pools have bridgeToken == address(0) and its description does not matter
            // (e.g. originOnly.LinkedPool.nUSD)
            if (pool.tokenAddress == address(0)) continue;
            // For the bridge pools, the description is the bridge token symbol
            string memory symbol = pool.description;
            // Record id (symbol) <> bridgeToken mapping, sanity check that there are no duplicates
            if (symbolToBridgeToken[symbol] != address(0)) {
                console2.log("Duplicate symbol: %s", symbol);
                revert("Duplicate symbol");
            }
            if (bytes(bridgeTokenToSymbol[pool.tokenAddress]).length != 0) {
                console2.log("Duplicate bridge token: %s", pool.tokenAddress);
                revert("Duplicate bridge token");
            }
            bridgeTokenToSymbol[pool.tokenAddress] = symbol;
            symbolToBridgeToken[symbol] = pool.tokenAddress;
        }
    }

    function setSynapseRouter() internal {
        address latestRouter = tryGetLatestRouterDeployment();
        if (quoterV2.synapseRouter() != latestRouter) {
            console2.log("Setting synapseRouter to %s", latestRouter);
            quoterV2.setSynapseRouter(latestRouter);
        }
    }

    function setPools() internal {
        SwapQuoterV2.BridgePool[] memory existingPools = getAllPools();
        // First, remove all bridge pools that are not in the config
        removeMissingPools(existingPools);
        // Then, add all pools from config that are not in the bridge pools
        addMissingPools(existingPools);
    }

    function getAllPools() internal view returns (SwapQuoterV2.BridgePool[] memory allPools) {
        address[] memory originDefaultPools = quoterV2.getOriginDefaultPools();
        address[] memory originLinkedPools = quoterV2.getOriginLinkedPools();
        SwapQuoterV2.BridgePool[] memory bridgePools = quoterV2.getBridgePools();
        // We need to add all origin pools to the bridge pools
        // bridgeToken for origin pools is address(0)
        uint256 totalPools = originDefaultPools.length + originLinkedPools.length + bridgePools.length;
        allPools = new SwapQuoterV2.BridgePool[](totalPools);
        uint256 index = 0;
        for (uint256 i = 0; i < originDefaultPools.length; (++i, ++index)) {
            allPools[index] = SwapQuoterV2.BridgePool({
                bridgeToken: address(0),
                poolType: SwapQuoterV2.PoolType.Default,
                pool: originDefaultPools[i]
            });
        }
        for (uint256 i = 0; i < originLinkedPools.length; (++i, ++index)) {
            allPools[index] = SwapQuoterV2.BridgePool({
                bridgeToken: address(0),
                poolType: SwapQuoterV2.PoolType.Linked,
                pool: originLinkedPools[i]
            });
        }
        for (uint256 i = 0; i < bridgePools.length; (++i, ++index)) {
            allPools[index] = bridgePools[i];
        }
    }

    function removeMissingPools(SwapQuoterV2.BridgePool[] memory existingPools) internal {
        // We need to remove pools with a bridge token that is not in the config
        SwapQuoterV2.BridgePool[] memory missingPools = getMissingPools({
            poolsToFilter: existingPools,
            existingPools: configBridgePools,
            comparePools: equalBridgeToken
        });
        printLog(StringUtils.concat("Removing ", missingPools.length.fromUint(), " pools"));
        if (missingPools.length == 0) {
            return;
        }
        increaseIndent();
        for (uint256 i = 0; i < missingPools.length; ++i) {
            printLog("Removing pool for %s -> %s", missingPools[i].bridgeToken, missingPools[i].pool);
        }
        quoterV2.removePools(missingPools);
        decreaseIndent();
    }

    function addMissingPools(SwapQuoterV2.BridgePool[] memory existingPools) internal {
        // We need to add pools from the config that are not in the bridge pools (checking all fields)
        SwapQuoterV2.BridgePool[] memory missingPools = getMissingPools({
            poolsToFilter: configBridgePools,
            existingPools: existingPools,
            comparePools: equalFully
        });
        printLog(StringUtils.concat("Adding ", missingPools.length.fromUint(), " pools"));
        if (missingPools.length == 0) {
            return;
        }
        increaseIndent();
        for (uint256 i = 0; i < missingPools.length; ++i) {
            string memory symbol = bridgeTokenToSymbol[missingPools[i].bridgeToken];
            string memory logString = symbol.concat(
                " [%s]: %s [",
                missingPools[i].poolType == SwapQuoterV2.PoolType.Linked ? "Linked" : "Default",
                "]"
            );
            printLog(logString, missingPools[i].bridgeToken, missingPools[i].pool);
        }
        quoterV2.addPools(missingPools);
        decreaseIndent();
    }

    // ══════════════════════════════════════════════ POOLS FILTERING ══════════════════════════════════════════════════

    /// @notice Checks if bridgeToken field in the two pools is equal.
    function equalBridgeToken(SwapQuoterV2.BridgePool memory pool0, SwapQuoterV2.BridgePool memory pool1)
        internal
        pure
        returns (bool)
    {
        // For origin pools (bridgeToken == address(0)), we check the pool address instead
        return pool0.bridgeToken == pool1.bridgeToken && (pool0.bridgeToken != address(0) || pool0.pool == pool1.pool);
    }

    /// @notice Checks if all fields in the two pools are equal.
    function equalFully(SwapQuoterV2.BridgePool memory pool0, SwapQuoterV2.BridgePool memory pool1)
        internal
        pure
        returns (bool)
    {
        return pool0.bridgeToken == pool1.bridgeToken && pool0.poolType == pool1.poolType && pool0.pool == pool1.pool;
    }

    /// @notice Returns a list of pools that are in `poolsToFilter` but not in `existingPools`.
    /// `comparePools` is a function that compares two pools and returns true if they are equal.
    function getMissingPools(
        SwapQuoterV2.BridgePool[] memory poolsToFilter,
        SwapQuoterV2.BridgePool[] memory existingPools,
        function(SwapQuoterV2.BridgePool memory, SwapQuoterV2.BridgePool memory)
            internal
            pure
            returns (bool) comparePools
    ) internal pure returns (SwapQuoterV2.BridgePool[] memory missingPools) {
        uint256 amountMissing = 0;
        bool[] memory found = new bool[](poolsToFilter.length);
        for (uint256 i = 0; i < poolsToFilter.length; ++i) {
            for (uint256 j = 0; j < existingPools.length; ++j) {
                if (comparePools(poolsToFilter[i], existingPools[j])) {
                    found[i] = true;
                    break;
                }
            }
            if (!found[i]) {
                ++amountMissing;
            }
        }
        missingPools = new SwapQuoterV2.BridgePool[](amountMissing);
        amountMissing = 0;
        for (uint256 i = 0; i < poolsToFilter.length; ++i) {
            if (!found[i]) {
                missingPools[amountMissing] = poolsToFilter[i];
                ++amountMissing;
            }
        }
    }
}
