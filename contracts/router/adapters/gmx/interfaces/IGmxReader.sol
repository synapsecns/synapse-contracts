// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGmxReader {
    function getMaxAmountIn(
        address _vault,
        address _tokenIn,
        address _tokenOut
    ) external view returns (uint256 maxAmountIn);

    function getAmountOut(
        address _vault,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256 amountOutAfterFees, uint256 feeAmount);
}
