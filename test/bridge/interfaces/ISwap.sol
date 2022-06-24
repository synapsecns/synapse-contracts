// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

interface ISwap {
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256);

    function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex)
        external
        view
        returns (uint256 availableTokenAmount);

    function getToken(uint8 index) external view returns (IERC20);

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external;
}
