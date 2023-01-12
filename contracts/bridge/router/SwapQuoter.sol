// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../libraries/BridgeStructs.sol";
import "./SwapCalculator.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Finds on-step trade paths between tokens using a set of
 * liquidity pools, that conform to ISwap interface.
 * Following set of methods is required for the pool to work (see ISwap.sol for details):
 * - getToken(uint8) external view returns (address);
 * - calculateSwap(uint8, uint8, uint256) external view returns (uint256);
 * - swap(uin8, uint8, uint256, uint256, uint256) external returns (uint256);
 */
contract SwapQuoter is SwapCalculator, Ownable {
    using ActionLib for uint256;

    /// @notice Address of SynapseRouter contract
    address public immutable synapseRouter;

    /// @notice Address of WGAS token used by SynapseBridge on the local chain
    address public immutable weth;

    constructor(address _synapseRouter, address _weth) public {
        synapseRouter = _synapseRouter;
        weth = _weth;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Adds a few pools to the list of pools used for finding a trade path.
     * @dev If any of the pools doesn't include WETH, one can use `weth = address(0)`.
     */
    function addPools(address[] calldata pools) external onlyOwner {
        uint256 amount = pools.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addPool(pools[i], weth);
        }
    }

    /**
     * @notice Adds a pool to the list of pools used for finding a trade path.
     * Stores all the supported pool tokens, and marks them as WETH, if they match the provided WETH address.
     * Also stores the pool LP token, if it exists.
     * @dev If the pool doesn't include WETH, one can use `weth = address(0)`.
     */
    function addPool(address pool) external onlyOwner {
        _addPool(pool, weth);
    }

    /**
     * @notice Removes a pool from the list of pools used for finding a trade path.
     */
    function removePool(address pool) external onlyOwner {
        _pools.remove(pool);
        // We don't remove _poolTokens records, as pool's set of tokens doesn't change over time.
        // Quoter iterates through all pools in `_pools`, so removing it from there is enough.
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Finds the best pool for tokenIn -> tokenOut swap from the list of supported pools.
     * Returns the `SwapQuery` struct, that can be used on SynapseRouter.
     * minAmountOut and deadline fields will need to be adjusted based on the swap settings.
     * @dev If tokenIn or tokenOut is ETH_ADDRESS, only the pools having WETH as a pool token will be considered.
     */
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (SwapQuery memory query) {
        if (tokenIn.token == tokenOut) {
            // Return struct indicating no swap is required
            return
                SwapQuery({
                    swapAdapter: address(0),
                    tokenOut: tokenIn.token,
                    minAmountOut: amountIn,
                    deadline: 0,
                    rawParams: bytes("")
                });
        }
        _checkHandleETH(tokenIn.token, tokenOut, amountIn, query, tokenIn.actionMask);
        uint256 amount = poolsAmount();
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            address lpToken = _poolLpToken[pool];
            (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(pool, tokenIn.token, tokenOut);
            // Check if both tokens are present in the current pool
            if (indexIn != 0 && indexOut != 0) {
                // Both tokens are in the pool
                // swap is required
                _checkSwapQuote(pool, indexIn, indexOut, amountIn, query, tokenIn.actionMask);
            } else if (tokenIn.token == lpToken && indexOut != 0) {
                // tokenIn is lpToken, tokenOut is in the pool
                // removeLiquidity is required
                _checkRemoveLiquidityQuote(pool, indexOut, amountIn, query, tokenIn.actionMask);
            } else if (indexIn != 0 && tokenOut == lpToken) {
                // tokenIn is in the pool, tokenOut is the lpToken
                // addLiquidity is required
                _checkAddLiquidityQuote(pool, indexIn, amountIn, query, tokenIn.actionMask);
            }
        }
        // Fill the remaining fields if a path was found
        if (query.minAmountOut != 0) {
            // Synapse Router should be used as "swap adapter" for doing a swap through Synapse pools
            query.swapAdapter = synapseRouter;
            query.tokenOut = tokenOut;
            // Set default deadline to infinity. Not using the value of 0,
            // which would lead to every swap to revert by default.
            query.deadline = type(uint256).max;
        }
    }

    /**
     * @notice Returns a list of all supported pools.
     */
    function allPools() external view override returns (Pool[] memory pools) {
        uint256 amount = poolsAmount();
        pools = new Pool[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            pools[i] = Pool({pool: pool, lpToken: _poolLpToken[pool], tokens: _poolTokens[pool]});
        }
    }

    /**
     * @notice Returns a list of pool tokens for the given pool.
     */
    function poolTokens(address pool) external view override returns (PoolToken[] memory tokens) {
        tokens = _poolTokens[pool];
    }

    /**
     * @notice Returns the amount of tokens the given pool supports and the pool's LP token.
     */
    function poolInfo(address pool) external view override returns (uint256 tokens, address lpToken) {
        tokens = _poolTokens[pool].length;
        lpToken = _poolLpToken[pool];
    }

    /**
     * @notice Returns the amount of supported pools.
     */
    function poolsAmount() public view override returns (uint256) {
        return _pools.length();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Checks a swap quote for the given pool, and updates `query`,
     * if output amount is better.
     */
    function _checkSwapQuote(
        address pool,
        uint8 indexIn,
        uint8 indexOut,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask
    ) internal view {
        // Don't do anything if we haven't specified Swap as possible action
        if (!actionMask.includes(Action.Swap)) return;
        uint8 tokenIndexFrom = indexIn - 1;
        uint8 tokenIndexTo = indexOut - 1;
        uint256 amountOut = _calculateSwap(pool, tokenIndexFrom, tokenIndexTo, amountIn);
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for swapping via the current pool
            query.rawParams = abi.encode(SynapseParams(Action.Swap, pool, tokenIndexFrom, tokenIndexTo));
        }
    }

    /**
     * @notice Checks a quote for adding liquidity to the given pool, and updates `query`,
     * if output amount is better.
     * This is the equivalent of tokenIn -> LPToken swap.
     */
    function _checkAddLiquidityQuote(
        address pool,
        uint8 indexIn,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask
    ) internal view {
        // Don't do anything if we haven't specified AddLiquidity as possible action
        if (!actionMask.includes(Action.AddLiquidity)) return;
        uint8 tokenIndexFrom = indexIn - 1;
        uint256 amountOut = _calculateAdd(pool, tokenIndexFrom, amountIn);
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for depositing to the current pool
            query.rawParams = abi.encode(SynapseParams(Action.AddLiquidity, pool, tokenIndexFrom, type(uint8).max));
        }
    }

    /**
     * @notice Checks a withdrawal quote for the given pool, and updates `query`,
     * if output amount is better.
     * This is the equivalent of LPToken -> tokenOut swap.
     */
    function _checkRemoveLiquidityQuote(
        address pool,
        uint8 indexOut,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask
    ) internal view {
        // Don't do anything if we haven't specified RemoveLiquidity as possible action
        if (!actionMask.includes(Action.RemoveLiquidity)) return;
        uint8 tokenIndexTo = indexOut - 1;
        uint256 amountOut = _calculateRemove(pool, tokenIndexTo, amountIn);
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for withdrawing from the current pool
            query.rawParams = abi.encode(SynapseParams(Action.RemoveLiquidity, pool, type(uint8).max, tokenIndexTo));
        }
    }

    function _checkHandleETH(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask
    ) internal view {
        // Don't do anything if we haven't specified HandleEth as possible action
        if (!actionMask.includes(Action.HandleEth)) return;
        if (
            (tokenIn == UniversalToken.ETH_ADDRESS && tokenOut == weth) ||
            (tokenIn == weth && tokenOut == UniversalToken.ETH_ADDRESS)
        ) {
            query.minAmountOut = amountIn;
            // Params for handling ETH: there is no pool, use -1 as indexes
            query.rawParams = abi.encode(SynapseParams(Action.HandleEth, address(0), type(uint8).max, type(uint8).max));
        }
    }
}
