// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LimitedToken, SwapQuery, Pool, PoolToken} from "../libs/Structs.sol";

/// @notice Interface for the SwapQuoterV1 version with updated pragma and enriched docs.
interface ISwapQuoterV1 {
    // ═══════════════════════════════════════════════ POOL GETTERS ════════════════════════════════════════════════════

    /// @notice Returns a list of all supported pools.
    function allPools() external view returns (Pool[] memory pools);

    /// @notice Returns the amount of supported pools.
    function poolsAmount() external view returns (uint256 amtPools);

    /// @notice Returns the number of tokens the given pool supports and the pool's LP token.
    function poolInfo(address pool) external view returns (uint256 numTokens, address lpToken);

    /// @notice Returns a list of pool tokens for the given pool.
    function poolTokens(address pool) external view returns (PoolToken[] memory tokens);

    // ══════════════════════════════════════════════ GENERAL QUOTES ═══════════════════════════════════════════════════

    /// @notice Checks if a swap is possible between every token in the given list
    /// and tokenOut, using any of the supported pools.
    /// @param tokensIn List of structs with following information:
    ///                 - actionMask    Bitmask representing what actions are available for doing tokenIn -> tokenOut
    ///                 - token         Token address to swap from
    /// @param tokenOut Token address to swap to
    /// @return amountFound     Amount of tokens from the list that are swappable to tokenOut
    /// @return isConnected     List of bool values, specifying whether a token from the list is swappable to tokenOut
    function findConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        returns (uint256 amountFound, bool[] memory isConnected);

    /// @notice Finds the best pool for a single tokenIn -> tokenOut swap from the list of supported pools.
    /// Returns the `SwapQuery` struct, that can be used on SynapseRouter.
    /// minAmountOut and deadline fields will need to be adjusted based on the swap settings.
    /// @dev If tokenIn or tokenOut is ETH_ADDRESS, only the pools having WETH as a pool token will be considered.
    /// Three potential outcomes are available:
    /// 1. `tokenIn` and `tokenOut` represent the same token address (identical tokens).
    /// 2. `tokenIn` and `tokenOut` represent different addresses. No trade path from `tokenIn` to `tokenOut` is found.
    /// 3. `tokenIn` and `tokenOut` represent different addresses. Trade path from `tokenIn` to `tokenOut` is found.
    /// The exact composition of the returned struct for every case is documented in the return parameter documentation.
    /// @param tokenIn  Struct with following information:
    ///                 - actionMask    Bitmask representing what actions are available for doing tokenIn -> tokenOut
    ///                 - token         Token address to swap from
    /// @param tokenOut Token address to swap to
    /// @param amountIn Amount of tokens to swap from
    /// @return query   Struct representing trade path between tokenIn and tokenOut:
    ///                 - swapAdapter: adapter address that would handle the swap. Address(0) if no path is found,
    ///                 or tokens are identical.
    ///                 - tokenOut: always equals to the provided `tokenOut`, even if no path if found.
    ///                 - minAmountOut: amount of `tokenOut`, if swap was completed now. 0, if no path is found.
    ///                 - deadline: 2**256-1 if path was found, or tokens are identical. 0, if no path is found.
    ///                 - rawParams: ABI-encoded SynapseParams struct indicating the swap parameters. Empty string,
    ///                 if no path is found, or tokens are identical.
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query);

    // ═══════════════════════════════════════════ SPECIFIC POOL QUOTES ════════════════════════════════════════════════

    /// @notice Returns the exact quote for adding liquidity to a given pool in a form of a single token.
    /// @dev The only way to get a quote for adding liquidity would be `pool.calculateTokenAmount()`,
    /// which gives an ESTIMATE: it doesn't take the trade fees into account.
    /// We do need the exact quotes for (DAI/USDC/USDT) -> nUSD "swaps" on Mainnet, hence we do this.
    /// We also need the exact quotes for adding liquidity to the pools.
    /// Note: the function might revert instead of returning 0 for incorrect requests. Make sure
    /// to take that into account.
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256 amountOut);

    /// @notice Returns the exact quote for swapping between two given tokens.
    /// @dev Exposes IDefaultPool.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut);

    /// @notice Returns the exact quote for withdrawing pools tokens in a balanced way.
    /// @dev Exposes IDefaultPool.calculateRemoveLiquidity(amount);
    function calculateRemoveLiquidity(address pool, uint256 amount) external view returns (uint256[] memory amountsOut);

    /// @notice Returns the exact quote for withdrawing a single pool token.
    /// @dev Exposes IDefaultPool.calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 amountOut);
}
