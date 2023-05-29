// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolQuoterV1} from "./PoolQuoterV1.sol";
import {ISwapQuoterV1, LimitedToken, SwapQuery, Pool, PoolToken} from "../interfaces/ISwapQuoterV1.sol";

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
        }
    }

    /// @inheritdoc ISwapQuoterV1
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query) {
        query = _findBestQuote(tokenIn, tokenOut, amountIn);
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
