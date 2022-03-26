// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISolidlyPair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getAmountOut(uint256 amountIn, address tokenIn)
        external
        view
        returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        );
}
