// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolQuoterV1} from "./PoolQuoterV1.sol";
import {ISwapQuoterV1, LimitedToken, SwapQuery, Pool, PoolToken} from "../interfaces/ISwapQuoterV1.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract SwapQuoterV2 is PoolQuoterV1, Ownable {
    constructor(
        address defaultPoolCalc,
        address weth,
        address owner_
    ) PoolQuoterV1(defaultPoolCalc, weth) {
        _transferOwnership(owner_);
    }

    // ════════════════════════════════════════════════ OWNER ONLY ═════════════════════════════════════════════════════

    /// @notice Adds a few pools to the list of pools used for finding a trade path.
    /// @dev The list should NOT include any UniversalSwap contracts.
    function addPools(address[] calldata pools) external onlyOwner {
        uint256 amount = pools.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addPool(pools[i]);
        }
    }

    /// @notice Adds a pool to the list of pools used for finding a trade path.
    /// @dev The pool should NOT be a UniversalSwap contract.
    function addPool(address pool) external onlyOwner {
        _addPool(pool);
    }

    /// @notice Removes a pool from the list of pools used for finding a trade path.
    function removePool(address pool) external onlyOwner {
        _removePool(pool);
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
}
