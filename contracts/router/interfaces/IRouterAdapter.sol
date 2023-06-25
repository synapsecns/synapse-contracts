// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRouterAdapter {
    /// @notice Performs a tokenIn -> tokenOut swap, according to the provided params.
    /// If tokenIn is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
    /// If tokenIn is ERC20, the tokens should be already transferred to this contract (using `msg.value = 0`).
    /// If tokenOut is ETH_ADDRESS, native ETH will be sent to the recipient (be aware of potential reentrancy).
    /// If tokenOut is ERC20, the tokens will be transferred to the recipient.
    /// @dev Contracts implementing {IRouterAdapter} interface are required to enforce the above restrictions.
    /// On top of that, they must ensure that exactly `amountOut` worth of `tokenOut` is transferred to the recipient.
    /// Swap deadline and slippage is checked outside of this contract.
    /// @param recipient    Address to receive the swapped token
    /// @param tokenIn      Token to sell (use ETH_ADDRESS to start from native ETH)
    /// @param amountIn     Amount of tokens to sell
    /// @param tokenOut     Token to buy (use ETH_ADDRESS to end with native ETH)
    /// @param rawParams    Additional swap parameters
    /// @return amountOut   Amount of bought tokens
    function adapterSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external payable returns (uint256 amountOut);
}
