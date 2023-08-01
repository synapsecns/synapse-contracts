// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolQuoterV1} from "./PoolQuoterV1.sol";
import {ISwapQuoterV1, LimitedToken, SwapQuery, Pool} from "../interfaces/ISwapQuoterV1.sol";
import {Action, ActionLib} from "../libs/Structs.sol";

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

    /// @notice Address of the SynapseRouter contract, which is used as "Router Adapter" for doing
    /// swaps through Default Pools (or handling ETH).
    address public synapseRouter;

    /// @dev Set of Default Pools that could be used for swaps on origin chain only
    EnumerableSet.AddressSet internal _defaultPools;
    /// @dev Set of Linked Pools that could be used for swaps on origin chain only
    EnumerableSet.AddressSet internal _linkedPools;

    /// @dev Mapping from a bridge token into a whitelisted liquidity pool for the token.
    /// Could be used for swaps on both origin and destination chains.
    mapping(address => TypedPool) internal _bridgePools;
    /// @dev Set of bridge tokens with whitelisted liquidity pools (keys for `_bridgePools` mapping)
    EnumerableSet.AddressSet internal _bridgeTokens;

    constructor(
        address synapseRouter_,
        address defaultPoolCalc_,
        address weth_,
        address owner_
    ) PoolQuoterV1(defaultPoolCalc_, weth_) {
        synapseRouter = synapseRouter_;
        transferOwnership(owner_);
    }

    // ═══════════════════════════════════════════ QUOTER V2 MANAGEMENT ════════════════════════════════════════════════

    /// @notice Allows to add a list of pools to SwapQuoterV2.
    /// - If bridgeToken is zero, the pool is added to the set of "origin pools" corresponding to the pool type:
    /// Default Pools for PoolType.Default, Linked Pools for PoolType.Linked.
    /// - Otherwise, the pool is added as the whitelisted pool for the bridge token. The pool could be used for swaps
    /// on both origin and destination chains.
    /// > Note: to update the whitelisted pool for the bridge token, supply the new pool with the same bridge token.
    /// > It is not required to remove the old pool first.
    /// @dev Will revert, if the pool is already added.
    function addPools(BridgePool[] memory pools) external onlyOwner {
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < pools.length; ++i) {
                _addPool(pools[i]);
            }
        }
    }

    /// @notice Allows to remove a list of pools from SwapQuoterV2.
    /// - If bridgeToken is zero, the pool is removed from the set of "origin pools" corresponding to the pool type:
    /// Default Pools for PoolType.Default, Linked Pools for PoolType.Linked.
    /// - Otherwise, the pool is removed as the whitelisted pool for the bridge token.
    /// @dev Will revert, if the pool is not added.
    function removePools(BridgePool[] memory pools) external onlyOwner {
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < pools.length; ++i) {
                _removePool(pools[i]);
            }
        }
    }

    /// @notice Allows to set the SynapseRouter contract, which is used as "Router Adapter" for doing
    /// swaps through Default Pools (or handling ETH).
    /// Note: this will not affect the old SynapseRouter contract which still uses this Quoter, as the old SynapseRouter
    /// could handle the requests with the new SynapseRouter as external "Router Adapter".
    function setSynapseRouter(address synapseRouter_) external onlyOwner {
        synapseRouter = synapseRouter_;
    }

    // ══════════════════════════════════════════════ QUOTER V2 VIEWS ══════════════════════════════════════════════════

    /// @notice Returns the list of Default Pools that could be used for swaps on origin chain only.
    function getDefaultPools() external view returns (address[] memory defaultPools) {
        return _defaultPools.values();
    }

    /// @notice Returns the list of Linked Pools that could be used for swaps on origin chain only.
    function getLinkedPools() external view returns (address[] memory linkedPools) {
        return _linkedPools.values();
    }

    /// @notice Returns the list of bridge tokens with whitelisted liquidity pools.
    /// The pools could be used for swaps on both origin and destination chains.
    function getBridgePools() external view returns (BridgePool[] memory bridgePools) {
        uint256 amtBridgePools = _bridgeTokens.length();
        bridgePools = new BridgePool[](amtBridgePools);
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < amtBridgePools; ++i) {
                address bridgeToken = _bridgeTokens.at(i);
                TypedPool memory typedPool = _bridgePools[bridgeToken];
                bridgePools[i] = BridgePool({
                    bridgeToken: bridgeToken,
                    poolType: typedPool.poolType,
                    pool: typedPool.pool
                });
            }
        }
    }

    // ═════════════════════════════════════════════ GENERAL QUOTES V1 ═════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function findConnectedTokens(LimitedToken[] memory bridgeTokensIn, address tokenOut)
        external
        view
        returns (uint256 amountFound, bool[] memory isConnected)
    {
        uint256 length = bridgeTokensIn.length;
        isConnected = new bool[](length);
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < length; ++i) {
                if (_isConnected(bridgeTokensIn[i].actionMask, bridgeTokensIn[i].token, tokenOut)) {
                    isConnected[i] = true;
                    // unchecked: ++amountFound never overflows uint256
                    ++amountFound;
                }
            }
        }
    }

    /// @inheritdoc ISwapQuoterV1
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query) {
        query = _getAmountOut(tokenIn.actionMask, tokenIn.token, tokenOut, amountIn);
        // tokenOut filed should always be populated, even if a path wasn't found
        query.tokenOut = tokenOut;
        // Fill the remaining fields if a path was found
        if (query.minAmountOut > 0) {
            // SynapseRouter should be used as "Router Adapter" for doing a swap through Default pools (or handling ETH),
            // as it inherits from DefaultAdapter.
            if (query.rawParams.length > 0) query.routerAdapter = synapseRouter;
            // Set default deadline to infinity. Not using the value of 0,
            // which would lead to every swap to revert by default.
            query.deadline = type(uint256).max;
        }
    }

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
        bool wasAdded = false;
        if (pool.bridgeToken == address(0)) {
            // No bridge token was supplied, so we add the pool to the corresponding set of "origin pools".
            // We also check that the pool has not been added yet.
            if (pool.poolType == PoolType.Default) {
                wasAdded = _defaultPools.add(pool.pool);
            } else {
                wasAdded = _linkedPools.add(pool.pool);
            }
        } else {
            address bridgeToken = pool.bridgeToken;
            // Bridge token was supplied, so we set the pool as the whitelisted pool for the bridge token.
            // We check that the old whitelisted pool is not the same as the new one.
            wasAdded = _bridgePools[bridgeToken].pool != pool.pool;
            // Add bridgeToken to the list of keys, if it wasn't added before
            _bridgeTokens.add(bridgeToken);
            _bridgePools[bridgeToken] = TypedPool({poolType: pool.poolType, pool: pool.pool});
        }
        require(wasAdded, "Pool has been added before");
    }

    /// @dev Removes a pool from SwapQuoterV2.
    /// - If bridgeToken is zero, the pool is removed from the set of pools corresponding to the pool type.
    /// - Otherwise, the pool is removed from the set of bridge pools.
    function _removePool(BridgePool memory pool) internal {
        bool wasRemoved = false;
        if (pool.bridgeToken == address(0)) {
            // No bridge token was supplied, so we remove the pool from the corresponding set of "origin pools".
            // We also check that the pool has been added before.
            if (pool.poolType == PoolType.Default) {
                wasRemoved = _defaultPools.remove(pool.pool);
            } else {
                wasRemoved = _linkedPools.remove(pool.pool);
            }
        } else {
            address bridgeToken = pool.bridgeToken;
            // Bridge token was supplied, so we remove the pool as the whitelisted pool for the bridge token.
            // We check that the old whitelisted pool is the same as the one we want to remove.
            // Note: we remove both the pool (value) and the bridge token (key).
            wasRemoved = _bridgeTokens.remove(bridgeToken) && _bridgePools[bridgeToken].pool == pool.pool;
            delete _bridgePools[pool.bridgeToken];
        }
        require(wasRemoved, "Unknown pool");
    }

    // ═════════════════════════════════════════ INTERNAL: POOL INSPECTION ═════════════════════════════════════════════

    /// @dev Returns the data for the given pool: pool address, LP token address (if applicable), and tokens.
    function _getPoolData(PoolType poolType, address pool) internal view returns (Pool memory poolData) {
        poolData.pool = pool;
        // Populate LP token field only for default pools
        if (poolType == PoolType.Default) poolData.lpToken = _lpToken(pool);
        poolData.tokens = _getPoolTokens(pool);
    }

    /// @dev Checks whether `tokenIn -> tokenOut` is possible given the `actionMask` of available actions for `tokenIn`.
    /// Will only consider the whitelisted pool for `tokenIn`
    function _isConnected(
        uint256 actionMask,
        address tokenIn,
        address tokenOut
    ) internal view returns (bool) {
        // If token addresses match, no action is required whatsoever.
        if (tokenIn == tokenOut) {
            return true;
        }
        // Check if ETH <> WETH (Action.HandleEth) could fulfill tokenIn -> tokenOut request.
        if (Action.HandleEth.isIncluded(actionMask) && _isEthAndWeth(tokenIn, tokenOut)) {
            return true;
        }
        TypedPool memory bridgePool = _bridgePools[tokenIn];
        // Do nothing, if tokenIn doesn't have a whitelisted pool
        if (bridgePool.pool == address(0)) return false;
        if (bridgePool.poolType == PoolType.Default) {
            // Check if Default Pool could fulfill tokenIn -> tokenOut request.
            return _isConnectedViaDefaultPool(actionMask, bridgePool.pool, tokenIn, tokenOut);
        } else {
            // Check if Linked Pool could fulfill tokenIn -> tokenOut request.
            return _isConnectedViaLinkedPool(actionMask, bridgePool.pool, tokenIn, tokenOut);
        }
    }

    /// @dev Returns the SwapQuery struct that could be used to fulfill `tokenIn -> tokenOut` request.
    /// - Will check all liquidity pools, if `actionMask` is set to the full set of actions.
    /// - Will only check the whitelisted pool for `tokenIn` otherwise.
    /// > Only populates the `minAmountOut` and `rawParams` fields, unless no trade path is found between the tokens.
    /// > Other fields are supposed to be populated in the caller function.
    function _getAmountOut(
        uint256 actionMask,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (SwapQuery memory query) {
        // If token addresses match, no action is required whatsoever.
        if (tokenIn == tokenOut) {
            query.minAmountOut = amountIn;
            // query.rawParams is "", indicating that no further action is required
            return query;
        }
        // Check if ETH <> WETH (Action.HandleEth) could fulfill tokenIn -> tokenOut request.
        _checkHandleETHQuote(actionMask, tokenIn, tokenOut, amountIn, query);
        // Check if this is a request for an origin swap.
        // These are given with the tokenIn.actionMask set to the full set of actions.
        if (actionMask != ActionLib.allActions()) {
            // This is a request for a destination swap. Only whitelisted pool for `tokenIn` is considered.
            TypedPool memory bridgePool = _bridgePools[tokenIn];
            _checkPoolQuote(actionMask, bridgePool, tokenIn, tokenOut, amountIn, query);
            return query;
        }
        unchecked {
            // If this is a request for an origin swap, check all available pools
            uint256 numPools = _defaultPools.length();
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < numPools; ++i) {
                _checkDefaultPoolQuote(actionMask, _defaultPools.at(i), tokenIn, tokenOut, amountIn, query);
            }
            numPools = _linkedPools.length();
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < numPools; ++i) {
                _checkLinkedPoolQuote(actionMask, _linkedPools.at(i), tokenIn, tokenOut, amountIn, query);
            }
            numPools = _bridgeTokens.length();
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < numPools; ++i) {
                TypedPool memory bridgePool = _bridgePools[_bridgeTokens.at(i)];
                _checkPoolQuote(actionMask, bridgePool, tokenIn, tokenOut, amountIn, query);
            }
        }
    }

    /// @dev Gets a quote for `tokenIn -> tokenOut` via the given Bridge Pool (either Default or Linked),
    /// given the `actionMask` of available actions for the token.
    /// If the action is possible, the `query` will be updated, should the output amount be better than
    /// the current best quote.
    function _checkPoolQuote(
        uint256 actionMask,
        TypedPool memory bridgePool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        SwapQuery memory query
    ) internal view {
        // Don't do anything, if no whitelisted pool exists.
        if (bridgePool.pool == address(0)) return;
        if (bridgePool.poolType == PoolType.Default) {
            _checkDefaultPoolQuote(actionMask, bridgePool.pool, tokenIn, tokenOut, amountIn, query);
        } else {
            _checkLinkedPoolQuote(actionMask, bridgePool.pool, tokenIn, tokenOut, amountIn, query);
        }
    }
}
