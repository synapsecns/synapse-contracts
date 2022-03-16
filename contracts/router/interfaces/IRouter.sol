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
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _amountOut);

    function swapFromGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external payable returns (uint256 _amountOut);

    function swapToGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _amountOut);

    // Bridge related functions [initial chain]

    function swapAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external;

    function swapFromGasAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external payable;

    // Bridge related functions [destination chain]

    function refundToAddress(
        address _token,
        uint256 _amount,
        address _to
    ) external;

    function selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _amountOut);
}
