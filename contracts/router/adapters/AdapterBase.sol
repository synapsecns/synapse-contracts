// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

abstract contract AdapterBase {
    using SafeERC20 for IERC20;

    uint256 internal constant UINT_MAX = type(uint256).max;

    /**
     * @dev Adapter is supposed to deal with ERC20 tokens only. Use WGAS instead of GAS.
     */
    receive() external payable {
        revert("Adapter does not accept GAS");
    }

    function isSwapSupported(address tokenIn, address tokenOut) external view returns (bool) {
        return _checkTokens(tokenIn, tokenOut);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Check allowance, and update if it is not big enough
     *
     * @param token token to check
     * @param amount minimum allowance that we need
     * @param spender address that will be given allowance
     */
    function _checkAllowance(
        IERC20 token,
        uint256 amount,
        address spender
    ) internal {
        uint256 _allowance = token.allowance(address(this), spender);
        if (_allowance < amount) {
            // safeApprove should only be called when setting an initial allowance,
            // or when resetting it to zero. (c) openzeppelin
            if (_allowance != 0) {
                token.safeApprove(spender, 0);
            }
            token.safeApprove(spender, UINT_MAX);
        }
    }

    /**
     * @notice Return expected funds to user
     *
     * @dev This will do nothing, if funds need to stay in this contract
     *
     * @param token address
     * @param amount tokens to return
     * @param to address where funds should be sent to
     */
    function _returnTo(
        address token,
        uint256 amount,
        address to
    ) internal {
        if (address(this) != to) {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _setInfiniteAllowance(IERC20 token, address spender) internal {
        _checkAllowance(token, UINT_MAX, spender);
    }

    /**
     * @notice Execute a swap with given input amount of tokens from tokenIn to tokenOut,
     *         assuming input tokens were transferred to depositAddress(tokenIn, tokenOut)
     *
     * @param amountIn input amount in starting token
     * @param tokenIn ERC20 token being sold
     * @param tokenOut ERC20 token being bought
     * @param to address where swapped funds should be sent to
     *
     * @return amountOut amount of tokenOut tokens received in swap
     */
    function _swapSafe(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) internal returns (uint256 amountOut) {
        require(amountIn != 0, "Insufficient input amount");
        require(to != address(0), "to cannot be zero address");
        require(tokenIn != tokenOut, "Tokens must differ");
        require(_checkTokens(tokenIn, tokenOut), "Tokens not supported");
        _approveIfNeeded(tokenIn, amountIn);
        amountOut = _swap(amountIn, tokenIn, tokenOut, to);
    }

    /**
     * @notice Get query for a swap through this adapter
     *
     * @param amountIn input amount in starting token
     * @param tokenIn ERC20 token being sold
     * @param tokenOut ERC20 token being bought
     */
    function _querySafe(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256) {
        if (amountIn == 0 || tokenIn == tokenOut || !_checkTokens(tokenIn, tokenOut)) {
            return 0;
        }
        return _query(amountIn, tokenIn, tokenOut);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          VIRTUAL FUNCTIONS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Approves token for the underneath swapper to use
     * @dev Implement via _checkAllowance(tokenIn, amount, POOL)
     *      only if it is not possible to set initial allowances in the constructor.
     *      Setting allowance for every swap is gas inefficient and provides
     *      zero security, as Adapter is not supposed to store tokens anyway.
     */
    function _approveIfNeeded(address, uint256) internal virtual {} // solhint-disable-line no-empty-blocks

    /// @dev Checks if a swap between two tokens is supported by adapter
    function _checkTokens(address tokenIn, address tokenOut) internal view virtual returns (bool);

    /**
     * @dev This aims to reduce the amount of token transfers:
     *      some (1) of underneath swappers will have the ability to receive tokens and then swap,
     *      while some (2) will only be able to pull tokens while swapping.
     *      Use swapper address for (1) and Adapter address for (2)
     */
    function _depositAddress(address tokenIn, address tokenOut) internal view virtual returns (address);

    /**
     * @dev 1. All variables are already checked
     *      2. Use _returnTo(tokenOut, amountOut, to) to return tokens, only if
     *         underneath swapper can't send swapped tokens to arbitrary address.
     *      3. Wrapping is handled external to this function
     *
     * @param amountIn amount being sold
     * @param tokenIn ERC20 token being sold
     * @param tokenOut ERC20 token being bought
     * @param to Where received tokens are sent to
     *
     * @return Amount of tokenOut tokens received in swap
     */
    function _swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) internal virtual returns (uint256);

    /**
     * @dev All variables are assumed to be checked.
     *      This should ALWAYS return amountOut such as: the swapper underneath
     *      is able to produce AT LEAST amountOut in exchange for EXACTLY amountIn
     *      For efficiency reasons, returning the exact quote is preferable,
     *      however, if the swapper doesn't have a reliable quoting method,
     *      it's safe to underquote the swapped amount
     *
     * @param amountIn input amount in starting token
     * @param tokenIn ERC20 token being sold
     * @param tokenOut ERC20 token being bought
     */
    function _query(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view virtual returns (uint256);
}
