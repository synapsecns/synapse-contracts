// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../libraries/BridgeStructs.sol";
import "./SwapCalculator.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Finds one-step trade paths between tokens using a set of
 * liquidity pools, that conform to ISwap interface.
 * Following set of methods is required for the pool to work (see ISwap.sol for details):
 * - getToken(uint8) external view returns (address);
 * - calculateSwap(uint8, uint8, uint256) external view returns (uint256);
 * - swap(uin8, uint8, uint256, uint256, uint256) external returns (uint256);
 * @dev SwapQuoter is supposed to work in conjunction with SynapseRouter.
 * For the correct behavior bridge token "liquidity pools" (or their pool wrappers) need to be added to SwapQuoter.
 * Adding any additional pools containing one of the bridge tokens could lead to incorrect bridge parameters.
 * Adding a pool that doesn't contain a single bridge token would be fine though.
 */
contract SwapQuoter is SwapCalculator, Ownable {
    using ActionLib for uint256;

    /// @notice Address of SynapseRouter contract.
    address public immutable synapseRouter;

    /// @notice Address of WETH token that is used by SynapseBridge.
    /// If SynapseBridge has WETH_ADDRESS set to address(0), this should point to chain's canonical WETH.
    address public immutable weth;

    uint256 private constant PATH_FOUND = 1;

    constructor(address _synapseRouter, address _weth) public {
        synapseRouter = _synapseRouter;
        weth = _weth;
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
            _addPool(pools[i], weth);
        }
    }

    /**
     * @notice Adds a pool to the list of pools used for finding a trade path.
     * Stores all the supported pool tokens, and marks them as WETH, if they match the WETH address.
     * Also stores the pool LP token, if it exists.
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
     * @notice Checks if a swap is possible between every token in the given list
     * and tokenOut, using any of the supported pools.
     * @param tokensIn  List of structs with following information:
     *                  - actionMask    Bitmask representing what actions are available for doing tokenIn -> tokenOut
     *                  - token         Token address to swap from
     * @param tokenOut  Token address to swap to
     * @return amountFound  Amount of tokens from the list that are swappable to tokenOut
     * @return isConnected  List of bool values, specifying whether a token from the list is swappable to tokenOut
     */
    function findConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        override
        returns (uint256 amountFound, bool[] memory isConnected)
    {
        uint256 amount = tokensIn.length;
        isConnected = new bool[](amount);
        SwapQuery memory query;
        for (uint256 i = 0; i < amount; ++i) {
            LimitedToken memory tokenIn = tokensIn[i];
            query = _getAmountOut(tokenIn, tokenOut, PATH_FOUND, false);
            if (query.minAmountOut == PATH_FOUND) {
                ++amountFound;
                isConnected[i] = true;
            }
        }
    }

    /**
     * @notice Finds the best pool for a single tokenIn -> tokenOut swap from the list of supported pools.
     * Returns the `SwapQuery` struct, that can be used on SynapseRouter.
     * minAmountOut and deadline fields will need to be adjusted based on the swap settings.
     * @dev If tokenIn or tokenOut is ETH_ADDRESS, only the pools having WETH as a pool token will be considered.
     * Three potential outcomes are available:
     * 1. `tokenIn` and `tokenOut` represent the same token address (identical tokens).
     * 2. `tokenIn` and `tokenOut` represent different addresses. No trade path from `tokenIn` to `tokenOut` is found.
     * 3. `tokenIn` and `tokenOut` represent different addresses. Trade path from `tokenIn` to `tokenOut` is found.
     * The exact composition of the returned struct for every case is documented in the return parameter documentation.
     * @param tokenIn   Struct with following information:
     *                  - actionMask    Bitmask representing what actions are available for doing tokenIn -> tokenOut
     *                  - token         Token address to swap from
     * @param tokenOut  Token address to swap to
     * @param amountIn  Amount of tokens to swap from
     * @return query    Struct representing trade path between tokenIn and tokenOut:
     *                  - swapAdapter: adapter address that would handle the swap. Address(0) if no path is found,
     *                  or tokens are identical.
     *                  - tokenOut: always equals to the provided `tokenOut`, even if no path if found.
     *                  - minAmountOut: amount of `tokenOut`, if swap was completed now. 0, if no path is found.
     *                  - deadline: 2**256-1 if path was found, or tokens are identical. 0, if no path is found.
     *                  - rawParams: ABI-encoded SynapseParams struct indicating the swap parameters. Empty string,
     *                  if no path is found, or tokens are identical.
     */
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (SwapQuery memory query) {
        query = _getAmountOut(tokenIn, tokenOut, amountIn, true);
        // tokenOut filed should always be populated, even if a path wasn't found
        query.tokenOut = tokenOut;
        // Fill the remaining fields if a path was found
        if (query.minAmountOut != 0) {
            // SynapseRouter should be used as "Swap Adapter" for doing a swap through Synapse pools (or handling ETH)
            if (query.rawParams.length != 0) query.swapAdapter = synapseRouter;
            // Set default deadline to infinity. Not using the value of 0,
            // which would lead to every swap to revert by default.
            query.deadline = type(uint256).max;
        }
    }

    /**
     * @dev Finds the best pool for a single tokenIn -> tokenOut swap from the list of supported pools.
     * Or, if `performQuoteCall` is set to False, checks if the above swap is possible via any of the supported pools.
     * Only populates the `minAmountOut` and `rawParams` fields, unless no trade path is found between the tokens.
     * Other fields are supposed to be populated in the caller function.
     */
    function _getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn,
        bool performQuoteCall
    ) internal view returns (SwapQuery memory query) {
        // If token addresses match, no action is required whatsoever.
        if (tokenIn.token == tokenOut) {
            // Form a SynapseRouter-compatible struct indicating no action is required.
            // Set amountOut to PATH_FOUND if we are only interested in whether the swap is possible
            query.minAmountOut = performQuoteCall ? amountIn : PATH_FOUND;
            // query.rawParams is "", indicating that no further action is required
            return query;
        }
        uint256 actionMask = tokenIn.actionMask;
        // Check if ETH <> WETH (Action.HandleEth) could fulfill tokenInglobal-bridge-zap -> tokenOut request.
        _checkHandleETH(tokenIn.token, tokenOut, amountIn, query, actionMask, performQuoteCall);
        uint256 amount = poolsAmount();
        // Struct to get around stack-too-deep error
        Pool memory _pool;
        for (uint256 i = 0; i < amount; ++i) {
            _pool.pool = _pools.at(i);
            _pool.lpToken = _poolLpToken[_pool.pool];
            (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(_pool.pool, tokenIn.token, tokenOut);
            if (indexIn != 0 && indexOut != 0) {
                // tokenIn, tokenOut are pool tokens: Action.Swap is required
                _checkSwapQuote(_pool.pool, indexIn, indexOut, amountIn, query, actionMask, performQuoteCall);
            } else if (tokenIn.token == _pool.lpToken && indexOut != 0) {
                // tokenIn is pool's LP Token, tokenOut is pool token: Action.RemoveLiquidity is required
                _checkRemoveLiquidityQuote(_pool.pool, indexOut, amountIn, query, actionMask, performQuoteCall);
            } else if (indexIn != 0 && tokenOut == _pool.lpToken) {
                // tokenIn is pool token, tokenOut is pool's LP token: Action.AddLiquidity is required
                _checkAddLiquidityQuote(_pool.pool, indexIn, amountIn, query, actionMask, performQuoteCall);
            }
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
     * @notice Checks a swap quote for the given pool, and updates `query` if output amount is better.
     * @dev Won't do anything if Action.Swap is not included in `actionMask`.
     */
    function _checkSwapQuote(
        address pool,
        uint8 indexIn,
        uint8 indexOut,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask,
        bool performQuoteCall
    ) internal view {
        // Don't do anything if we haven't specified Swap as possible action
        if (!actionMask.includes(Action.Swap)) return;
        uint8 tokenIndexFrom = indexIn - 1;
        uint8 tokenIndexTo = indexOut - 1;
        // Set amountOut to PATH_FOUND if we are only interested in whether the swap is possible
        uint256 amountOut = performQuoteCall
            ? _calculateSwap(pool, tokenIndexFrom, tokenIndexTo, amountIn)
            : PATH_FOUND;
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for swapping via the current pool: specify indexFrom and indexTo
            query.rawParams = abi.encode(SynapseParams(Action.Swap, pool, tokenIndexFrom, tokenIndexTo));
        }
    }

    /**
     * @notice Checks a quote for adding liquidity to the given pool, and updates `query` if output amount is better.
     * This is the equivalent of tokenIn -> LPToken swap.
     * @dev Won't do anything if Action.AddLiquidity is not included in `actionMask`.
     */
    function _checkAddLiquidityQuote(
        address pool,
        uint8 indexIn,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask,
        bool performQuoteCall
    ) internal view {
        // Don't do anything if we haven't specified AddLiquidity as possible action
        if (!actionMask.includes(Action.AddLiquidity)) return;
        uint8 tokenIndexFrom = indexIn - 1;
        // Set amountOut to PATH_FOUND if we are only interested in whether the swap is possible
        uint256 amountOut = performQuoteCall ? _calculateAdd(pool, tokenIndexFrom, amountIn) : PATH_FOUND;
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for depositing to the current pool: specify indexFrom, indexTo = -1
            query.rawParams = abi.encode(SynapseParams(Action.AddLiquidity, pool, tokenIndexFrom, type(uint8).max));
        }
    }

    /**
     * @notice Checks a withdrawal quote for the given pool, and updates `query` if output amount is better.
     * This is the equivalent of LPToken -> tokenOut swap.
     * @dev Won't do anything if Action.RemoveLiquidity is not included in `actionMask`.
     */
    function _checkRemoveLiquidityQuote(
        address pool,
        uint8 indexOut,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask,
        bool performQuoteCall
    ) internal view {
        // Don't do anything if we haven't specified RemoveLiquidity as possible action
        if (!actionMask.includes(Action.RemoveLiquidity)) return;
        uint8 tokenIndexTo = indexOut - 1;
        // Set amountOut to PATH_FOUND if we are only interested in whether the swap is possible
        uint256 amountOut = performQuoteCall ? _calculateRemove(pool, tokenIndexTo, amountIn) : PATH_FOUND;
        // We want to return the best available quote
        if (amountOut > query.minAmountOut) {
            query.minAmountOut = amountOut;
            // Encode params for withdrawing from the current pool: indexFrom = -1, specify indexTo
            query.rawParams = abi.encode(SynapseParams(Action.RemoveLiquidity, pool, type(uint8).max, tokenIndexTo));
        }
    }

    /**
     * @notice Checks if a "handle ETH" operation is possible between two given tokens.
     * That would be either unwrapping WETh into native ETH, or wrapping ETH into WETH.
     * @dev Won't do anything if Action.HandleEth is not included in `actionMask`.
     */
    function _checkHandleETH(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        SwapQuery memory query,
        uint256 actionMask,
        bool performQuoteCall
    ) internal view {
        // Don't do anything if we haven't specified HandleEth as possible action
        if (!actionMask.includes(Action.HandleEth)) return;
        if (
            (tokenIn == UniversalToken.ETH_ADDRESS && tokenOut == weth) ||
            (tokenIn == weth && tokenOut == UniversalToken.ETH_ADDRESS)
        ) {
            // Set amountOut to PATH_FOUND if we are only interested in whether the swap is possible
            query.minAmountOut = performQuoteCall ? amountIn : PATH_FOUND;
            // Params for handling ETH: there is no pool, use -1 as indexes
            query.rawParams = abi.encode(SynapseParams(Action.HandleEth, address(0), type(uint8).max, type(uint8).max));
        }
    }
}
