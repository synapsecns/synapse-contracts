// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicRouter} from "./IBasicRouter.sol";

interface IRouter is IBasicRouter {
    event Swap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    // Single chain swaps

    function swap(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);

    function swapFromGAS(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable returns (uint256 amountOut);

    function swapToGAS(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);
}
