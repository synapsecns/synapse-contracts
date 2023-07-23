// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../interfaces/IDefaultPoolCalc.sol";
import {IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {ISwapQuoterV1, PoolToken, SwapQuery} from "../interfaces/ISwapQuoterV1.sol";
import {Action, DefaultParams} from "../libs/Structs.sol";
import {UniversalTokenLib} from "../libs/UniversalToken.sol";

/// @notice Stateless abstraction to calculate exact quotes for any DefaultPool instances.
abstract contract PoolQuoterV1 is ISwapQuoterV1 {
    IDefaultPoolCalc internal immutable _defaultPoolCalc;
    address internal immutable _weth;

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

    // ══════════════════════════════════════════════ POOL GETTERS V1 ══════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function poolInfo(address pool) external view returns (uint256 numTokens, address lpToken) {
        numTokens = _numTokens(pool);
        lpToken = _lpToken(pool);
    }

    /// @inheritdoc ISwapQuoterV1
    function poolTokens(address pool) external view returns (PoolToken[] memory tokens) {
        tokens = _getPoolTokens(pool);
    }

    // ══════════════════════════════════════════════ POOL INSPECTION ══════════════════════════════════════════════════

    /// @dev Returns the LP token address for the given pool, if it exists. Otherwise, returns address(0).
    function _lpToken(address pool) internal view returns (address) {
        // Try getting the LP token address from the pool.
        try IDefaultExtendedPool(pool).swapStorage() returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address lpToken
        ) {
            return lpToken;
        } catch {
            // Return address(0) if the pool doesn't have an LP token.
            return address(0);
        }
    }

    /// @dev Returns the number of tokens the given pool supports.
    function _numTokens(address pool) internal view returns (uint256 numTokens) {
        while (true) {
            // Iterate over the tokens until we get an exception.
            try IDefaultExtendedPool(pool).getToken(uint8(numTokens)) returns (address) {
                unchecked {
                    // unchecked: ++numTokens never overflows uint256
                    ++numTokens;
                }
            } catch {
                // End of pool reached, exit the loop.
                break;
            }
        }
    }

    /// @dev Returns the tokens the given pool supports.
    function _getPoolTokens(address pool) internal view returns (PoolToken[] memory tokens) {
        uint256 numTokens = _numTokens(pool);
        tokens = new PoolToken[](numTokens);
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < numTokens; ++i) {
                address token = IDefaultExtendedPool(pool).getToken(uint8(i));
                tokens[i] = PoolToken({isWeth: token == _weth, token: token});
            }
        }
    }

    // ════════════════════════════════════════════ POOL QUOTE CHECKERS ════════════════════════════════════════════════

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
        uint256[] memory amounts = new uint256[](_numTokens(pool));
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
