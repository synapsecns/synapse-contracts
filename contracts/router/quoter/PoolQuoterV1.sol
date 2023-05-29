// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../interfaces/IDefaultPoolCalc.sol";
import {IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {ISwapQuoterV1, SwapQuery} from "../interfaces/ISwapQuoterV1.sol";
import {UniversalTokenLib} from "../libs/UniversalToken.sol";

import {Action, LimitedToken, Pool, PoolToken, DefaultParams} from "../libs/Structs.sol";

import {EnumerableSet} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableSet.sol";

/// @notice Abstraction to calculate quotes for a given DefaultPool
abstract contract PoolQuoterV1 is ISwapQuoterV1 {
    using EnumerableSet for EnumerableSet.AddressSet;

    IDefaultPoolCalc internal immutable _defaultPoolCalc;
    address internal immutable _weth;

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    // All Default Pools that are supported by this quoter. Note: This excludes UniversalSwap wrappers.
    EnumerableSet.AddressSet internal _pools;
    /// @dev Pool tokens for every supported IDefaultPool pool
    mapping(address => PoolToken[]) internal _poolTokens;
    /// @dev LP token for every supported IDefaultPool pool (if exists)
    mapping(address => address) internal _poolLpToken;

    constructor(address defaultPoolCalc, address weth) {
        _defaultPoolCalc = IDefaultPoolCalc(defaultPoolCalc);
        _weth = weth;
    }

    // ═══════════════════════════════════════════ SPECIFIC POOL QUOTES ════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256 amountOut) {
        // Forward the only getter that is not properly implemented in the StableSwap contract (DefaultPool).
        return _defaultPoolCalc.calculateAddLiquidity(pool, amounts);
    }

    /// @inheritdoc ISwapQuoterV1
    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        return IDefaultExtendedPool(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    /// @inheritdoc ISwapQuoterV1
    function calculateRemoveLiquidity(address pool, uint256 amount)
        external
        view
        returns (uint256[] memory amountsOut)
    {
        return IDefaultExtendedPool(pool).calculateRemoveLiquidity(amount);
    }

    /// @inheritdoc ISwapQuoterV1
    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 amountOut) {
        return IDefaultExtendedPool(pool).calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
    }

    // ═══════════════════════════════════════════════ POOL GETTERS ════════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function allPools() external view returns (Pool[] memory pools) {
        uint256 amount = _pools.length();
        pools = new Pool[](amount);
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            pools[i] = Pool({pool: pool, lpToken: _poolLpToken[pool], tokens: _poolTokens[pool]});
        }
    }

    /// @inheritdoc ISwapQuoterV1
    function poolsAmount() external view returns (uint256 tokens) {
        return _pools.length();
    }

    /// @inheritdoc ISwapQuoterV1
    function poolInfo(address pool) external view returns (uint256 tokens, address lpToken) {
        tokens = _poolTokens[pool].length;
        lpToken = _poolLpToken[pool];
    }

    /// @inheritdoc ISwapQuoterV1
    function poolTokens(address pool) external view returns (PoolToken[] memory tokens) {
        tokens = _poolTokens[pool];
    }

    // ══════════════════════════════════════════════ POOL MANAGEMENT ══════════════════════════════════════════════════

    /// @dev Adds a pool to the list of pools, and saves its tokens if done for the first time.
    function _addPool(address pool) internal {
        if (_pools.add(pool)) {
            PoolToken[] storage tokens = _poolTokens[pool];
            // Don't do anything if pool was added before
            if (tokens.length != 0) return;
            for (uint8 i = 0; ; ++i) {
                try IDefaultExtendedPool(pool).getToken(i) returns (address token) {
                    PoolToken memory poolToken = PoolToken({isWeth: address(token) == _weth, token: address(token)});
                    _poolTokens[pool].push(poolToken);
                } catch {
                    // End of pool reached
                    break;
                }
            }
            try IDefaultExtendedPool(pool).swapStorage() returns (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address lpToken
            ) {
                _poolLpToken[pool] = lpToken;
            } catch {
                // solhint-disable-previous-line no-empty-blocks
                // Don't do anything if swapStorage fails, this is probably a IDefaultPool wrapper contract
            }
        }
    }

    /// @dev Removes a pool from the list of pools. Leaves the records of its tokens intact in case it is added again.
    function _removePool(address pool) internal {
        _pools.remove(pool);
        // We don't clear _poolTokens or _poolLpToken, as pool's set of tokens doesn't change over time.
        // PoolQuoterV1 iterates through all pools in `_pools`, so removing it from there is enough.
    }

    // ════════════════════════════════════════════ FINDING QUOTE LOGIC ════════════════════════════════════════════════

    /// @dev Returns pool indexes for the two given tokens plus 1.
    /// - The default value of 0 means a token is not supported by the pool.
    /// - If one of the pool tokens is WETH, ETH_ADDRESS is also considered as a pool token.
    function _getTokenIndexes(
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint8 indexIn, uint8 indexOut) {
        PoolToken[] storage tokens = _poolTokens[pool];
        uint256 amount = tokens.length;
        for (uint8 t = 0; t < amount; ++t) {
            address poolToken = tokens[t].token;
            if (tokenIn == poolToken || _isEthAndWeth(tokenIn, poolToken)) {
                indexIn = t + 1;
            } else if (tokenOut == poolToken || _isEthAndWeth(tokenOut, poolToken)) {
                indexOut = t + 1;
            }
        }
    }

    /// @dev Finds the best pool for a single tokenIn -> tokenOut action from the list of supported pools.
    /// - If no pool is found, returns an empty SwapQuery.
    /// - Otherwise, only populates `minAmountOut` and `rawParams` fields of `query`.
    /// - Action.HandleEth is used if (tokenIn, tokenOut) is either (ETH, WETH) or (WETH, ETH).
    /// - Action.Swap is used if (tokenIn, tokenOut) are tokens from the same supported pool.
    /// - Action.AddLiquidity is used if tokenIn is a pool token, and tokenOut is the pool LP token.
    /// - Action.RemoveLiquidity is used if tokenIn is the pool LP token, and tokenOut is a pool token.
    function _findBestQuote(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (SwapQuery memory query) {
        // If token addresses match, no action is required whatsoever.
        if (tokenIn.token == tokenOut) {
            // Form a SynapseRouter-compatible struct indicating no action is required.
            // query.rawParams is left empty, as it is not required for this action.
            query.minAmountOut = amountIn;
            return query;
        }
        // Check if ETH <> WETH (Action.HandleEth) could fulfill tokenIn -> tokenOut request.
        _checkHandleETH(tokenIn.actionMask, tokenIn.token, tokenOut, amountIn, query);
        uint256 amount = _pools.length();
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            address lpToken = _poolLpToken[pool];
            // Check if tokenIn and tokenOut are pool tokens
            (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(pool, tokenIn.token, tokenOut);
            if (indexIn > 0 && indexOut > 0) {
                // tokenIn, tokenOut are pool tokens: Action.Swap is required
                unchecked {
                    _checkSwapQuote(tokenIn.actionMask, pool, indexIn - 1, indexOut - 1, amountIn, query);
                }
            } else if (tokenOut == lpToken && indexIn > 0) {
                // tokenIn is pool token, tokenOut is LP token: Action.AddLiquidity is required
                unchecked {
                    _checkAddLiquidityQuote(tokenIn.actionMask, pool, indexIn - 1, amountIn, query);
                }
            } else if (tokenIn.token == lpToken && indexOut > 0) {
                // tokenIn is LP token, tokenOut is pool token: Action.RemoveLiquidity is required
                unchecked {
                    _checkRemoveLiquidityQuote(tokenIn.actionMask, pool, indexOut - 1, amountIn, query);
                }
            }
        }
    }

    /// @dev Checks if a single tokenIn -> tokenOut action is available via any of the supported pools.
    function _isConnected(LimitedToken memory tokenIn, address tokenOut) internal view returns (bool isConnected) {
        // If token addresses match, no action is required whatsoever.
        if (tokenIn.token == tokenOut) {
            return true;
        }
        // Check if ETH <> WETH (Action.HandleEth) could fulfill tokenIn -> tokenOut request.
        if (Action.HandleEth.isIncluded(tokenIn.actionMask) && _isEthAndWeth(tokenIn.token, tokenOut)) {
            return true;
        }
        uint256 amount = _pools.length();
        for (uint256 i = 0; i < amount; ++i) {
            address pool = _pools.at(i);
            address lpToken = _poolLpToken[pool];
            // Check if tokenIn and tokenOut are pool tokens
            (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(pool, tokenIn.token, tokenOut);
            if (indexIn > 0 && indexOut > 0) {
                // tokenIn, tokenOut are pool tokens: Action.Swap is required
                isConnected = isConnected || Action.Swap.isIncluded(tokenIn.actionMask);
            } else if (tokenOut == lpToken && indexIn > 0) {
                // tokenIn is pool token, tokenOut is LP token: Action.AddLiquidity is required
                isConnected = isConnected || Action.AddLiquidity.isIncluded(tokenIn.actionMask);
            } else if (tokenIn.token == lpToken && indexOut > 0) {
                // tokenIn is LP token, tokenOut is pool token: Action.RemoveLiquidity is required
                isConnected = isConnected || Action.RemoveLiquidity.isIncluded(tokenIn.actionMask);
            }
        }
    }

    // ════════════════════════════════════════════ CHECK QUOTES LOGIC ═════════════════════════════════════════════════

    /// @dev Checks a swap quote for the given pool, updates `query` if output amount is better.
    /// - tokenIn -> tokenOut swap will be considered.
    /// - Won't do anything if Action.Swap is not included in `actionMask`.
    function _checkSwapQuote(
        uint256 actionMask,
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountIn,
        SwapQuery memory query
    ) internal view {
        // Don't do anything if we haven't specified Swap as possible action
        if (!Action.Swap.isIncluded(actionMask)) return;
        try IDefaultExtendedPool(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, amountIn) returns (
            uint256 amountOut
        ) {
            if (amountOut > query.minAmountOut) {
                query.minAmountOut = amountOut;
                // Encode params for swapping via the current pool: specify indexFrom and indexTo
                query.rawParams = abi.encode(DefaultParams(Action.Swap, pool, tokenIndexFrom, tokenIndexTo));
            }
        } catch {
            // solhint-disable-previous-line no-empty-blocks
            // If swap quote fails, we just ignore it
        }
    }

    /// @dev Checks a quote for adding liquidity to the given pool, and updates `query` if output amount is better.
    /// - This is the equivalent of tokenIn -> LPToken swap.
    /// - Won't do anything if Action.AddLiquidity is not included in `actionMask`.
    function _checkAddLiquidityQuote(
        uint256 actionMask,
        address pool,
        uint8 tokenIndexFrom,
        uint256 amountIn,
        SwapQuery memory query
    ) internal view {
        // Don't do anything if we haven't specified AddLiquidity as possible action
        if (!Action.AddLiquidity.isIncluded(actionMask)) return;
        uint256[] memory amounts = new uint256[](_poolTokens[pool].length);
        amounts[tokenIndexFrom] = amountIn;
        // Use DefaultPool Calc as we need the exact quote here
        try _defaultPoolCalc.calculateAddLiquidity(pool, amounts) returns (uint256 amountOut) {
            if (amountOut > query.minAmountOut) {
                query.minAmountOut = amountOut;
                // Encode params for adding liquidity via the current pool: specify indexFrom (indexTo = 0xFF)
                query.rawParams = abi.encode(DefaultParams(Action.AddLiquidity, pool, tokenIndexFrom, type(uint8).max));
            }
        } catch {
            // solhint-disable-previous-line no-empty-blocks
            // If addLiquidity quote fails, we just ignore it
        }
    }

    /// @dev Checks a quote for removing liquidity from the given pool, and updates `query` if output amount is better.
    /// - This is the equivalent of LPToken -> tokenOut swap.
    /// - Won't do anything if Action.RemoveLiquidity is not included in `actionMask`.
    function _checkRemoveLiquidityQuote(
        uint256 actionMask,
        address pool,
        uint8 tokenIndexTo,
        uint256 amountIn,
        SwapQuery memory query
    ) internal view {
        // Don't do anything if we haven't specified RemoveLiquidity as possible action
        if (!Action.RemoveLiquidity.isIncluded(actionMask)) return;
        try IDefaultExtendedPool(pool).calculateRemoveLiquidityOneToken(amountIn, tokenIndexTo) returns (
            uint256 amountOut
        ) {
            if (amountOut > query.minAmountOut) {
                query.minAmountOut = amountOut;
                // Encode params for removing liquidity via the current pool: specify indexTo (indexFrom = 0xFF)
                query.rawParams = abi.encode(
                    DefaultParams(Action.RemoveLiquidity, pool, type(uint8).max, tokenIndexTo)
                );
            }
        } catch {
            // solhint-disable-previous-line no-empty-blocks
            // If removeLiquidity quote fails, we just ignore it
        }
    }

    /// @dev Checks if a "handle ETH" operation is possible between two given tokens.
    /// - That would be either unwrapping WETH into native ETH, or wrapping ETH into WETH.
    /// - Won't do anything if Action.HandleEth is not included in `actionMask`.
    function _checkHandleETH(
        uint256 actionMask,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        SwapQuery memory query
    ) internal view {
        // Don't do anything if we haven't specified HandleETH as possible action
        if (!Action.HandleEth.isIncluded(actionMask)) return;
        if (_isEthAndWeth(tokenIn, tokenOut)) {
            query.minAmountOut = amountIn;
            // Encode params for handling ETH: no pool is present, indexFrom and indexTo are 0xFF
            query.rawParams = abi.encode(DefaultParams(Action.HandleEth, address(0), type(uint8).max, type(uint8).max));
        }
    }

    /// @dev Checks that (tokenA, tokenB) is either (ETH, WETH) or (WETH, ETH).
    function _isEthAndWeth(address tokenA, address tokenB) internal view returns (bool) {
        return
            (tokenA == UniversalTokenLib.ETH_ADDRESS && tokenB == _weth) ||
            (tokenA == _weth && tokenB == UniversalTokenLib.ETH_ADDRESS);
    }
}
