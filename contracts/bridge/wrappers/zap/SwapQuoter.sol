// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../interfaces/ISwapQuoter.sol";
import "../../libraries/BridgeStructs.sol";
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
contract SwapQuoter is SwapCalculator, Ownable, ISwapQuoter {
    /// @notice Address of BridgeZap contract
    address public immutable bridgeZap;

    constructor(address _bridgeZap) public {
        bridgeZap = _bridgeZap;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Adds a few pools to the list of pools used for finding a trade path.
     */
    function addPools(address[] calldata pools) external onlyOwner {
        uint256 amount = pools.length;
        for (uint256 i = 0; i < amount; ++i) {
            _addPool(pools[i]);
        }
    }

    /**
     * @notice Adds a pool to the list of pools used for finding a trade path.
     * Stores all the supported pool tokens, and the pool LP token, if it exists.
     */
    function addPool(address pool) external onlyOwner {
        _addPool(pool);
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
     * Returns the `SwapQuery` struct, that can be used on BridgeZap.
     * minAmountOut and deadline fields will need to be adjusted based on the swap settings.
     */
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (SwapQuery memory query) {
        if (tokenIn == tokenOut) {
            // Return struct indicating no swap is required
            return
                SwapQuery({
                    swapAdapter: address(0),
                    tokenOut: tokenIn,
                    minAmountOut: amountIn,
                    deadline: 0,
                    rawParams: bytes("")
                });
        }
        uint256 amount = poolsAmount();
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            address lpToken = _poolLpToken[pool];
            (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(pool, tokenIn, tokenOut);
            // Check if both tokens are present in the current pool
            if (indexIn != 0 && indexOut != 0) {
                // Both tokens are in the pool
                // swap is required
                _checkSwapQuote(pool, indexIn, indexOut, amountIn, query);
            } else if (tokenIn == lpToken && indexOut != 0) {
                // tokenIn is lpToken, tokenOut is in the pool
                // removeLiquidity is required
                _checkRemoveLiquidityQuote(pool, indexOut, amountIn, query);
            } else if (indexIn != 0 && tokenOut == lpToken) {
                // tokenIn is in the pool, tokenOut is the lpToken
                // addLiquidity is required
                _checkAddLiquidityQuote(pool, indexIn, amountIn, query);
            }
        }
        // Fill the remaining fields if a path was found
        if (query.minAmountOut != 0) {
            // Bridge Zap should be used for doing a swap through Synapse pools
            query.swapAdapter = bridgeZap;
            query.tokenOut = tokenOut;
            // Set default deadline to infinity. Not using the value of 0,
            // which would lead to every swap to revert by default.
            query.deadline = type(uint256).max;
        }
    }

    /**
     * @notice Returns a list of all supported pools.
     */
    function allPools() external view returns (address[] memory pools) {
        uint256 amount = poolsAmount();
        pools = new address[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            pools[i] = _pools.at(i);
        }
    }

    /**
     * @notice Returns a list of pool tokens for the given pool.
     */
    function poolTokens(address pool) external view returns (address[] memory tokens) {
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
    function poolsAmount() public view returns (uint256) {
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
        SwapQuery memory query
    ) internal view {
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
        SwapQuery memory query
    ) internal view {
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
        SwapQuery memory query
    ) internal view {
        uint8 tokenIndexTo = indexOut - 1;
        uint256 amountOut = _calculateRemove(pool, tokenIndexTo, amountIn);
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for withdrawing from the current pool
            query.rawParams = abi.encode(SynapseParams(Action.RemoveLiquidity, pool, type(uint8).max, tokenIndexTo));
        }
    }
}
