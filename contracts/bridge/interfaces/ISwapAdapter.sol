// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../libraries/BridgeStructs.sol";

interface ISwapAdapter {
    /**
     * @notice Performs a tokenIn -> tokenOut swap, according to the provided params,
     * assuming tokenIn was already transferred to this contract.
     * @dev Swap deadline and slippage is checked outside of this contract.
     * @param to            Address to receive the swapped token
     * @param tokenIn       Token to sell
     * @param amountIn      Amount of tokens to sell
     * @param tokenOut      Token to buy
     * @param rawParams     Additional swap parameters
     * @return Amount of bought tokens
     */
    function adapterSwap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external returns (uint256);
}
