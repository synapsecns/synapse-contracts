// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, PoolQuoterV1} from "./PoolQuoterV1.sol";
import {ISwapQuoterV1, LimitedToken, SwapQuery, Pool, PoolToken} from "../interfaces/ISwapQuoterV1.sol";
import {ILinkedPool} from "../interfaces/ILinkedPool.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableSet.sol";

contract SwapQuoterV2 is PoolQuoterV1, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable synapseRouter;

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    EnumerableSet.AddressSet internal _linkedPools;

    constructor(
        address synapseRouter_,
        address defaultPoolCalc,
        address weth,
        address owner_
    ) PoolQuoterV1(defaultPoolCalc, weth) {
        synapseRouter = synapseRouter_;
        _transferOwnership(owner_);
    }

    // ════════════════════════════════════════════════ OWNER ONLY ═════════════════════════════════════════════════════

    /// @notice Adds a few pools to the list of pools used for finding a trade path.
    /// @dev The list should NOT include any LinkedPool contracts.
    function addPools(address[] calldata pools) external onlyOwner {
        uint256 amount = pools.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addPool(pools[i]);
        }
    }

    /// @notice Adds a pool to the list of pools used for finding a trade path.
    /// @dev The pool should NOT be a LinkedPool contract.
    function addPool(address pool) external onlyOwner {
        _addPool(pool);
    }

    /// @notice Removes a pool from the list of pools used for finding a trade path.
    function removePool(address pool) external onlyOwner {
        _removePool(pool);
    }

    /// @notice Adds a few LinkedPool contracts for finding a trade path.
    function addLinkedPools(address[] calldata linkedPools) external onlyOwner {
        uint256 amount = linkedPools.length;
        for (uint256 i = 0; i < amount; ++i) {
            _linkedPools.add(linkedPools[i]);
        }
    }

    /// @notice Adds a LinkedPool contract for finding a trade path.
    function addLinkedPool(address linkedPool) external onlyOwner {
        _linkedPools.add(linkedPool);
    }

    /// @notice Removes a LinkedPool contract from the list of contracts used for finding a trade path.
    function removeLinkedPool(address linkedPool) external onlyOwner {
        _linkedPools.remove(linkedPool);
    }

    // ══════════════════════════════════════════ UNIVERSAL SWAP GETTERS ═══════════════════════════════════════════════

    /// @notice Returns the list of LinkedPool contracts used for finding a trade path.
    function allLinkedPools() external view returns (address[] memory linkedPools) {
        return _linkedPools.values();
    }

    /// @notice Returns the amount of LinkedPool contracts used for finding a trade path.
    function linkedPoolsAmount() external view returns (uint256 amount) {
        return _linkedPools.length();
    }

    // ═════════════════════════════════════════════ GENERAL QUOTES V1 ═════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function findConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        returns (uint256 amountFound, bool[] memory isConnected)
    {
        uint256 amount = tokensIn.length;
        isConnected = new bool[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            if (_isConnected(tokensIn[i], tokenOut)) {
                isConnected[i] = true;
                ++amountFound;
            }
            // Convert to pool tokens for following LinkedPool requests (which is unaware of ETH/WETH interactions)
            tokensIn[i].token = _poolToken(tokensIn[i].token);
        }
        tokenOut = _poolToken(tokenOut);
        uint256 length = _linkedPools.length();
        for (uint256 i = 0; i < length; ++i) {
            // Check what tokens are connected to tokenOut through LinkedPool
            bool[] memory connectedViaPool = ILinkedPool(_linkedPools.at(i)).getConnectedTokens(tokensIn, tokenOut);
            // Update the result
            for (uint256 j = 0; j < amount; ++j) {
                // We only care about tokens that weren't connected before
                if (connectedViaPool[j] && !isConnected[j]) {
                    isConnected[j] = true;
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
        // First, find best quote using only DefaultPools
        query = _findBestQuote(tokenIn, tokenOut, amountIn);
        // Check LinkedPools if `tokenIn.actionMask` allows to do a swap
        if (Action.Swap.isIncluded(tokenIn.actionMask)) {
            // This is a request for destination swap (bridge token -> final token) if only Swap action is allowed,
            // as per SynapseRouter implementation. Otherwise, it's an origin swap (tokenIn -> bridge token),
            // or a general quote request (tokenIn -> tokenOut).
            bool isDestinationSwap = tokenIn.actionMask == Action.Swap.mask();
            // Convert to pool tokens for following LinkedPool requests (which is unaware of ETH/WETH interactions)
            address poolTokenIn = _poolToken(tokenIn.token);
            address poolTokenOut = _poolToken(tokenOut);
            uint256 length = _linkedPools.length();
            for (uint256 i = 0; i < length; ++i) {
                address pool = _linkedPools.at(i);
                // If this is a destination swap, tokenIn represents a bridge token.
                // Bridge token has a single whitelisted pool, which would be the LinkedPool having
                // the bridge token as a root token. We need to skip the other pools, as it won't be
                // possible to swap the bridge token in them.
                if (isDestinationSwap && poolTokenIn != ILinkedPool(pool).getToken(0)) continue;
                // For origin swaps any pool could be used, so we don't check the root token.
                // Check if the LinkedPool contract can find a better quote
                (uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 amountOut) = ILinkedPool(pool).findBestPath(
                    poolTokenIn,
                    poolTokenOut,
                    amountIn
                );
                if (amountOut > query.minAmountOut) {
                    query.minAmountOut = amountOut;
                    query.rawParams = _encodeSwapParams(pool, tokenIndexFrom, tokenIndexTo);
                }
            }
        }
        // tokenOut filed should always be populated, even if a path wasn't found
        query.tokenOut = tokenOut;
        // Fill the remaining fields if a path was found
        if (query.minAmountOut > 0) {
            // SynapseRouter is used as "Router Adapter" for doing a swap through Default Pools (or handling ETH).
            // query.rawParams is left empty only if tokenIn == tokenOut (if no swap or ETH operation is required).
            if (query.rawParams.length > 0) query.routerAdapter = synapseRouter;
            // Set default deadline to infinity. Not using the value of 0,
            // which would lead to every swap to revert by default.
            query.deadline = type(uint256).max;
        }
    }
}
