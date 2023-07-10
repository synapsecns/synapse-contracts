// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IVelodromeV2Pool {
    function stable() external view returns (bool);

    function factory() external view returns (address);

    function tokens() external view returns (address token0, address token1);

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}
