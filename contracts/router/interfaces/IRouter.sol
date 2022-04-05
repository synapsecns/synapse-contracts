// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicRouter} from "./IBasicRouter.sol";

interface IRouter is IBasicRouter {
    event Swap(
        address indexed _tokenIn,
        address indexed _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut
    );

    // Single chain swaps

    function swap(
        address _to,
        address[] calldata _path,
        address[] calldata _adapters,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256 _amountOut);

    function swapFromGAS(
        address _to,
        address[] calldata _path,
        address[] calldata _adapters,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external payable returns (uint256 _amountOut);

    function swapToGAS(
        address _to,
        address[] calldata _path,
        address[] calldata _adapters,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256 _amountOut);
}
