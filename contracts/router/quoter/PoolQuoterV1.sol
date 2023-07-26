// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../interfaces/IDefaultPoolCalc.sol";
import {IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {ILinkedPool} from "../interfaces/ILinkedPool.sol";
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

    /// @dev Returns pool indexes for the two given tokens plus 1.
    /// - The default value of 0 means a token is not supported by the pool.
    /// - If one of the pool tokens is WETH, ETH_ADDRESS is also considered as a pool token.
    /// Note: this is not supposed to be used with LinkedPool contracts, as a single token can appear
    /// multiple times in the LinkedPool's token tree.
    function _getTokenIndexes(
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint8 indexIn, uint8 indexOut) {
        uint256 numTokens = _numTokens(pool);
        unchecked {
            // unchecked: numTokens <= 255 => ++t never overflows uint8
            for (uint8 t = 0; t < numTokens; ++t) {
                address poolToken = IDefaultExtendedPool(pool).getToken(t);
                if (_poolToken(tokenIn) == poolToken) {
                    // unchecked: (t + 1) never overflows uint8 (see above)
                    indexIn = t + 1;
                }
                if (_poolToken(tokenOut) == poolToken) {
                    // unchecked: (t + 1) never overflows uint8 (see above)
                    indexOut = t + 1;
                }
            }
        }
    }

    // ════════════════════════════════════════ POOL TOKEN -> TOKEN QUOTES ═════════════════════════════════════════════

    /// @dev Checks whether `tokenIn -> tokenOut` is possible via the given Default Pool, given the
    /// `actionMask` of available actions for the token.
    /// Note: only checks DefaultPool-related actions: Swap/AddLiquidity/RemoveLiquidity.
    function _isConnectedViaDefaultPool(
        uint256 actionMask,
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (bool) {
        (uint8 indexIn, uint8 indexOut) = _getTokenIndexes(pool, tokenIn, tokenOut);
        // Check if Swap (tokenIn -> tokenOut) could fulfill tokenIn -> tokenOut request.
        if (Action.Swap.isIncluded(actionMask) && indexIn > 0 && indexOut > 0) {
            return true;
        }
        address lpToken = _lpToken(pool);
        // Check if AddLiquidity (tokenIn -> lpToken) could fulfill tokenIn -> tokenOut request.
        if (Action.AddLiquidity.isIncluded(actionMask) && indexIn > 0 && tokenOut == lpToken) {
            return true;
        }
        // Check if RemoveLiquidity (lpToken -> tokenOut) could fulfill tokenIn -> tokenOut request.
        if (Action.RemoveLiquidity.isIncluded(actionMask) && tokenIn == lpToken && indexOut > 0) {
            return true;
        }
        return false;
    }

    /// @dev Checks whether `tokenIn -> tokenOut` is possible via the given Linked Pool, given the
    /// `actionMask` of available actions for the token.
    /// Note: only checks LinkedPool-related actions: Swap.
    function _isConnectedViaLinkedPool(
        uint256 actionMask,
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (bool) {
        // Check if Swap (tokenIn -> tokenOut) could fulfill tokenIn -> tokenOut request.
        if (Action.Swap.isIncluded(actionMask)) {
            // Check if tokenIn and tokenOut are connected via the LinkedPool.
            return ILinkedPool(pool).areConnectedTokens(tokenIn, tokenOut);
        }
        return false;
    }

    // ════════════════════════════════════════ POOL INDEX -> INDEX QUOTES ═════════════════════════════════════════════

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
        if (_isEthAndWeth(tokenIn, tokenOut)) {
            query.minAmountOut = amountIn;
            // Encode params for handling ETH: no pool is present, indexFrom and indexTo are 0xFF
            query.rawParams = abi.encode(DefaultParams(Action.HandleEth, address(0), type(uint8).max, type(uint8).max));
        }
    }

    // ═════════════════════════════════════════ INTERNAL UTILS: ETH, WETH ═════════════════════════════════════════════

    /// @dev Checks that (tokenA, tokenB) is either (ETH, WETH) or (WETH, ETH).
    function _isEthAndWeth(address tokenA, address tokenB) internal view returns (bool) {
        return
            (tokenA == UniversalTokenLib.ETH_ADDRESS && tokenB == _weth) ||
            (tokenA == _weth && tokenB == UniversalTokenLib.ETH_ADDRESS);
    }

    /// @dev Returns token address used in the pool for the given token.
    /// This is either the token itself, or WETH if the token is ETH.
    function _poolToken(address token) internal view returns (address) {
        return token == UniversalTokenLib.ETH_ADDRESS ? _weth : token;
    }
}
