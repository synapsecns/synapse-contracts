// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterBase} from "./AdapterBase.sol";
import {IAdapter} from "../interfaces/IAdapter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

abstract contract Adapter is Ownable, AdapterBase, IAdapter {
    using SafeERC20 for IERC20;

    string public name;
    uint256 public swapGasEstimate;

    uint256 internal constant UINT_MAX = type(uint256).max;

    constructor(string memory _name, uint256 _swapGasEstimate) {
        name = _name;
        setSwapGasEstimate(_swapGasEstimate);
    }

    /**
     * @notice Fallback function
     * @dev use recoverGAS() to recover GAS sent to this contract
     */
    receive() external payable {
        // silence the linter
        this;
    }

    /// @dev this is estimated amount of gas that's used by swap() implementation
    function setSwapGasEstimate(uint256 _swapGasEstimate) public onlyOwner {
        swapGasEstimate = _swapGasEstimate;
        emit UpdatedGasEstimate(address(this), _swapGasEstimate);
    }

    // -- RESTRICTED ALLOWANCE FUNCTIONS --

    function setInfiniteAllowance(IERC20 token, address spender) external onlyOwner {
        _setInfiniteAllowance(token, spender);
    }

    /**
     * @notice Revoke token allowance
     *
     * @param token address
     * @param spender address
     */
    function revokeTokenAllowance(IERC20 token, address spender) external onlyOwner {
        token.safeApprove(spender, 0);
    }

    // -- RESTRICTED RECOVER TOKEN FUNCTIONS --

    /**
     * @notice Recover ERC20 from contract
     * @param token token to recover
     */
    function recoverERC20(IERC20 token) external onlyOwner {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "Adapter: Nothing to recover");

        emit Recovered(address(token), amount);
        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Recover GAS from contract
     */
    function recoverGAS() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Adapter: Nothing to recover");

        emit Recovered(address(0), amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "GAS transfer failed");
    }

    /**
     * @return Address to transfer tokens in order for swap() to work
     */

    function depositAddress(address tokenIn, address tokenOut) external view returns (address) {
        return _depositAddress(tokenIn, tokenOut);
    }

    /**
     * @notice Get query for a swap through this adapter
     *
     * @param amountIn input amount in starting token
     * @param tokenIn ERC20 token being sold
     * @param tokenOut ERC20 token being bought
     */
    function query(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256) {
        if (amountIn == 0 || tokenIn == tokenOut || !_checkTokens(tokenIn, tokenOut)) {
            return 0;
        }
        return _query(amountIn, tokenIn, tokenOut);
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
    function swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) external returns (uint256 amountOut) {
        require(amountIn != 0, "Insufficient input amount");
        require(to != address(0), "to cannot be zero address");
        require(tokenIn != tokenOut, "Tokens must differ");
        require(_checkTokens(tokenIn, tokenOut), "Tokens not supported");
        _approveIfNeeded(tokenIn, amountIn);
        amountOut = _swap(amountIn, tokenIn, tokenOut, to);
    }

    // -- INTERNAL FUNCTIONS

    /**
     * @notice Return expected funds to user
     *
     * @dev this will do nothing, if funds need to stay in this contract
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

    function _setInfiniteAllowance(IERC20 token, address spender) internal {
        _checkAllowance(token, UINT_MAX, spender);
    }

    // -- INTERNAL VIRTUAL FUNCTIONS

    /**
     * @notice Approves token for the underneath swapper to use
     *
     * @dev Implement via _checkAllowance(tokenIn, amount, POOL)
     *      if actually needed
     */
    function _approveIfNeeded(address, uint256) internal virtual {} // solhint-disable-line no-empty-blocks

    /**
     * @notice Internal implementation for depositAddress
     *
     * @dev This aims to reduce the amount of extra token transfers:
     *      some (1) of underneath swappers will have the ability to receive tokens and then swap,
     *      while some (2) will only be able to pull tokens while swapping.
     *      Use swapper address for (1) and Adapter address for (2)
     */
    function _depositAddress(address tokenIn, address tokenOut) internal view virtual returns (address);

    /**
     * @notice Internal implementation of a swap
     *
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
     * @notice Internal implementation of query
     *
     * @dev All variables are already checked.
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
