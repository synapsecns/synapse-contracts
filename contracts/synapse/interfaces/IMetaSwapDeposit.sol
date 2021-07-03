// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

interface IMetaSwapDeposit {
  // min return calculation functions
  function calculateSwap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx
  ) external view returns (uint256);

  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) external returns (uint256);

  function getToken(uint256 index) external view returns (IERC20);
}
