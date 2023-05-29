// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../interfaces/IDefaultPoolCalc.sol";
import {IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {ISwapQuoterV1, SwapQuery} from "../interfaces/ISwapQuoterV1.sol";
import {UniversalTokenLib} from "../libs/UniversalToken.sol";

import {Action, Pool, PoolToken, DefaultParams} from "../libs/Structs.sol";

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
        if (
            (tokenIn == UniversalTokenLib.ETH_ADDRESS && tokenOut == _weth) ||
            (tokenIn == _weth && tokenOut == UniversalTokenLib.ETH_ADDRESS)
        ) {
            query.minAmountOut = amountIn;
            // Encode params for handling ETH: no pool is present, indexFrom and indexTo are 0xFF
            query.rawParams = abi.encode(DefaultParams(Action.HandleEth, address(0), type(uint8).max, type(uint8).max));
        }
    }
}
