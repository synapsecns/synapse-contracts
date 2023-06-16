// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// TODO: migrate this to `router` folder
import {IDefaultPool} from "../../cctp/interfaces/IDefaultPool.sol";
import {IRouterAdapter} from "../interfaces/IRouterAdapter.sol";
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
        IDefaultPool pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {}

    /// @dev Adds liquidity in a form of a single token to the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _addLiquidity(
        IDefaultPool pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {}

    /// @dev Removes liquidity in a form of a single token from the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _removeLiquidity(
        IDefaultPool pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {}

    // ════════════════════════════════════════ INTERNAL LOGIC: ETH <> WETH ════════════════════════════════════════════

    /// @dev Wraps ETH into WETH.
    function _wrapETH(address weth, uint256 amount) internal {}

    /// @dev Unwraps WETH into ETH.
    function _unwrapETH(address weth, uint256 amount) internal {}
}
