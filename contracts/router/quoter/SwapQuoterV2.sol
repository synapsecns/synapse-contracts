// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolQuoterV1} from "./PoolQuoterV1.sol";
import {ISwapQuoterV1, LimitedToken, SwapQuery, Pool} from "../interfaces/ISwapQuoterV1.sol";

import {EnumerableSet} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract SwapQuoterV2 is PoolQuoterV1, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Defines the type of supported liquidity pool.
    /// - Default: pool that implements the IDefaultPool interface, which is either the StableSwap pool
    /// or a wrapper contract around the non-standard pool that conforms to the interface.
    /// - Linked: LinkedPool contract, which is a wrapper for arbitrary amount of liquidity pools to
    /// be used for multi-hop swaps.
    enum PoolType {
        Default,
        Linked
    }

    /// @notice Struct that is used for storing the whitelisted liquidity pool for a bridge token.
    /// @dev Occupies a single storage slot.
    /// @param poolType     Type of the pool: Default or Linked.
    /// @param pool         Address of the whitelisted pool.
    struct TypedPool {
        PoolType poolType;
        address pool;
    }

    /// @notice Struct that is used as a argument/return value for pool management functions.
    /// Therefore, it is not used internally and does not occupy any storage slots.
    /// @dev `bridgeToken` can be set to zero, in which case struct defines a pool
    /// that could be used for swaps on origin chain only.
    /// @param bridgeToken  Address of the bridge token.
    /// @param poolType     Type of the pool: Default or Linked.
    /// @param pool         Address of the whitelisted pool.
    struct BridgePool {
        address bridgeToken;
        PoolType poolType;
        address pool;
    }

    /// @dev Set of Default Pools that could be used for swaps on origin chain only
    EnumerableSet.AddressSet internal _defaultPools;
    /// @dev Set of Linked Pools that could be used for swaps on origin chain only
    EnumerableSet.AddressSet internal _linkedPools;

    /// @dev Mapping from a bridge token into a whitelisted liquidity pool for the token.
    /// Could be used for swaps on both origin and destination chains.
    mapping(address => TypedPool) internal _bridgePools;
    /// @dev Set of bridge tokens with whitelisted liquidity pools (keys for `_bridgePools` mapping)
    EnumerableSet.AddressSet internal _bridgeTokens;

    // solhint-disable-next-line no-empty-blocks
    constructor(address defaultPoolCalc, address weth) PoolQuoterV1(defaultPoolCalc, weth) {}

    // ══════════════════════════════════════════════ POOL MANAGEMENT ══════════════════════════════════════════════════

    function addPools(BridgePool[] memory pools) external onlyOwner {
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < pools.length; ++i) {
                _addPool(pools[i]);
            }
        }
    }

    function removePools(BridgePool[] memory pools) external onlyOwner {
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < pools.length; ++i) {
                _removePool(pools[i]);
            }
        }
    }

    // ═════════════════════════════════════════════ GENERAL QUOTES V1 ═════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function findConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        returns (uint256 amountFound, bool[] memory isConnected)
    {}

    /// @inheritdoc ISwapQuoterV1
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query) {}

    // ══════════════════════════════════════════════ POOL GETTERS V1 ══════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function allPools() external view returns (Pool[] memory pools) {
        // Combine Default, Linked, and Bridge pools into a single array
        uint256 amtDefaultPools = _defaultPools.length();
        uint256 amtLinkedPools = _linkedPools.length();
        uint256 amtBridgePools = _bridgeTokens.length();
        unchecked {
            // unchecked: total amount of pools never overflows uint256
            pools = new Pool[](amtDefaultPools + amtLinkedPools + amtBridgePools);
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < amtDefaultPools; ++i) {
                pools[i] = _getPoolData(PoolType.Default, _defaultPools.at(i));
            }
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < amtLinkedPools; ++i) {
                // unchecked: amtDefaultPools + i < pools.length => never overflows
                pools[amtDefaultPools + i] = _getPoolData(PoolType.Linked, _linkedPools.at(i));
            }
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < amtBridgePools; ++i) {
                address bridgeToken = _bridgeTokens.at(i);
                TypedPool memory typedPool = _bridgePools[bridgeToken];
                // unchecked: amtDefaultPools + amtLinkedPools + i < pools.length => never overflows uint256
                pools[amtDefaultPools + amtLinkedPools + i] = _getPoolData(typedPool.poolType, typedPool.pool);
            }
        }
    }

    /// @inheritdoc ISwapQuoterV1
    function poolsAmount() external view returns (uint256 amtPools) {
        // Total amount of pools is the sum of pools in each pool type and bridge pools
        unchecked {
            // unchecked: total amount of pools never overflows uint256
            return _defaultPools.length() + _linkedPools.length() + _bridgeTokens.length();
        }
    }

    // ═════════════════════════════════════════ INTERNAL: POOL MANAGEMENT ═════════════════════════════════════════════

    /// @dev Adds a pool to SwapQuoterV2.
    /// - If bridgeToken is zero, the pool is added to the set of pools corresponding to the pool type.
    /// - Otherwise, the pool is added to the set of bridge pools.
    function _addPool(BridgePool memory pool) internal {
        if (pool.bridgeToken == address(0)) {
            if (pool.poolType == PoolType.Default) {
                _defaultPools.add(pool.pool);
            } else {
                _linkedPools.add(pool.pool);
            }
        } else {
            _bridgeTokens.add(pool.bridgeToken);
            _bridgePools[pool.bridgeToken] = TypedPool({poolType: pool.poolType, pool: pool.pool});
        }
    }

    /// @dev Removes a pool from SwapQuoterV2.
    /// - If bridgeToken is zero, the pool is removed from the set of pools corresponding to the pool type.
    /// - Otherwise, the pool is removed from the set of bridge pools.
    function _removePool(BridgePool memory pool) internal {
        if (pool.bridgeToken == address(0)) {
            if (pool.poolType == PoolType.Default) {
                _defaultPools.remove(pool.pool);
            } else {
                _linkedPools.remove(pool.pool);
            }
        } else {
            _bridgeTokens.remove(pool.bridgeToken);
            delete _bridgePools[pool.bridgeToken];
        }
    }

    // ═════════════════════════════════════════ INTERNAL: POOL INSPECTION ═════════════════════════════════════════════

    /// @dev Returns the data for the given pool: pool address, LP token address (if applicable), and tokens.
    function _getPoolData(PoolType poolType, address pool) internal view returns (Pool memory poolData) {
        poolData.pool = pool;
        // Populate LP token field only for default pools
        if (poolType == PoolType.Default) poolData.lpToken = _lpToken(pool);
        poolData.tokens = _getPoolTokens(pool);
    }
}
