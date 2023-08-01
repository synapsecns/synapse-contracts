// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IGMXV1Vault} from "./IGMXV1Vault.sol";

interface IGMXV1Reader {
    function getAmountOut(
        IGMXV1Vault _vault,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256 amountOutAfterFees, uint256 feeAmount);

    function getMaxAmountIn(
        IGMXV1Vault _vault,
        address _tokenIn,
        address _tokenOut
    ) external view returns (uint256);
}
