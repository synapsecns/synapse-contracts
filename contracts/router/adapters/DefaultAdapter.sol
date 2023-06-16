// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPool, IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {IRouterAdapter} from "../interfaces/IRouterAdapter.sol";
import {TokenAddressMismatch} from "../libs/Errors.sol";
import {DefaultParams} from "../libs/Structs.sol";
import {UniversalTokenLib} from "../libs/UniversalToken.sol";

contract DefaultAdapter is IRouterAdapter {
    using UniversalTokenLib for address;

    /// @inheritdoc IRouterAdapter
    function adapterSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes memory rawParams
    ) external payable returns (uint256 amountOut) {
        return _adapterSwap(recipient, tokenIn, amountIn, tokenOut, rawParams);
    }

    /// @dev Internal logic for doing a tokenIn -> tokenOut swap.
    /// Note: `tokenIn` is assumed to have already been transferred to this contract.
    function _adapterSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes memory rawParams
    ) internal returns (uint256 amountOut) {}

    // ═══════════════════════════════════════ INTERNAL LOGIC: SWAP ACTIONS ════════════════════════════════════════════

    /// @dev Performs a swap through the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _swap(
        address pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the "swap to" token
        if (IDefaultPool(pool).getToken(params.tokenIndexTo) != tokenOut) revert TokenAddressMismatch();
        // amountOut and deadline are not checked in RouterAdapter
        amountOut = IDefaultPool(pool).swap({
            tokenIndexFrom: params.tokenIndexFrom,
            tokenIndexTo: params.tokenIndexTo,
            dx: amountIn,
            minDy: 0,
            deadline: type(uint256).max
        });
    }

    /// @dev Adds liquidity in a form of a single token to the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _addLiquidity(
        address pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        uint256 numTokens = _getPoolNumTokens(pool);
        address lpToken = _getPoolLPToken(pool);
        // tokenOut should match the LP token
        if (lpToken != tokenOut) revert TokenAddressMismatch();
        uint256[] memory amounts = new uint256[](numTokens);
        amounts[params.tokenIndexFrom] = amountIn;
        // amountOut and deadline are not checked in RouterAdapter
        amountOut = IDefaultExtendedPool(pool).addLiquidity({
            amounts: amounts,
            minToMint: 0,
            deadline: type(uint256).max
        });
    }

    /// @dev Removes liquidity in a form of a single token from the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _removeLiquidity(
        address pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the "swap to" token
        if (IDefaultPool(pool).getToken(params.tokenIndexTo) != tokenOut) revert TokenAddressMismatch();
        // amountOut and deadline are not checked in RouterAdapter
        amountOut = IDefaultExtendedPool(pool).removeLiquidityOneToken({
            tokenAmount: amountIn,
            tokenIndex: params.tokenIndexTo,
            minAmount: 0,
            deadline: type(uint256).max
        });
    }

    // ═════════════════════════════════════════ INTERNAL LOGIC: POOL LENS ═════════════════════════════════════════════

    /// @dev Returns the LP token address of the given pool.
    function _getPoolLPToken(address pool) internal view returns (address lpToken) {
        (, , , , , , lpToken) = IDefaultExtendedPool(pool).swapStorage();
    }

    /// @dev Returns the number of tokens in the given pool.
    function _getPoolNumTokens(address pool) internal view returns (uint256 numTokens) {
        // Iterate over all tokens in the pool until the end is reached
        for (uint8 index = 0; ; ++index) {
            try IDefaultPool(pool).getToken(index) returns (address) {} catch {
                // End of pool reached
                numTokens = index;
                break;
            }
        }
    }

    // ════════════════════════════════════════ INTERNAL LOGIC: ETH <> WETH ════════════════════════════════════════════

    /// @dev Wraps ETH into WETH.
    function _wrapETH(address weth, uint256 amount) internal {}

    /// @dev Unwraps WETH into ETH.
    function _unwrapETH(address weth, uint256 amount) internal {}
}
