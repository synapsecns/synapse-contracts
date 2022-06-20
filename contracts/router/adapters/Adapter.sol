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

    constructor(string memory _name, uint256 _swapGasEstimate) {
        name = _name;
        setSwapGasEstimate(_swapGasEstimate);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function setInfiniteAllowance(IERC20 token, address spender) external onlyOwner {
        _setInfiniteAllowance(token, spender);
    }

    /// @dev this is estimated amount of gas that's used by swap() implementation
    function setSwapGasEstimate(uint256 _swapGasEstimate) public onlyOwner {
        swapGasEstimate = _swapGasEstimate;
        emit UpdatedGasEstimate(address(this), _swapGasEstimate);
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          EXTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

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
        return _querySafe(amountIn, tokenIn, tokenOut);
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
    ) external returns (uint256) {
        return _swapSafe(amountIn, tokenIn, tokenOut, to);
    }
}
