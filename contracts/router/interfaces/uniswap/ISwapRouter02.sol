// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// For some reason deadline field is missing in Avalanche's SwapRouter02
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

interface ISwapRouter02 {
    function exactInputSingle(ExactInputSingleParams memory params) external payable returns (uint256 amountOut);
}
