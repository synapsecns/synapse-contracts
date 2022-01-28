// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import {IERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/IERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts-4.4.2/token/ERC20/extensions/ERC20Burnable.sol";

interface ISynapseBridge {

  function deposit(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) external;

  function depositAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) external;

  function redeem(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) external;

  function redeemAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) external;

  function redeemAndRemove(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 liqTokenIndex,
    uint256 liqMinAmount,
    uint256 liqDeadline
  ) external;

  function kappaExists(bytes32 kappa) external view returns (bool);

  function getFeeBalance(address tokenAddress) external view returns (uint256);
}
