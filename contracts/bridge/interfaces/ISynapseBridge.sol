// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

import {IERC20Mintable} from '../interfaces/IERC20Mintable.sol';

interface ISynapseBridge {
  using SafeERC20 for IERC20;

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

  // events

  event TokenDeposit(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  );

  event TokenRedeem(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  );

  event TokenWithdraw(
    address indexed to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    bytes32 indexed kappa
  );

  event TokenMint(
    address indexed to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    bytes32 indexed kappa
  );

  event TokenDepositAndSwap(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  );

  event TokenMintAndSwap(
    address indexed to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline,
    bool swapSuccess,
    bytes32 indexed kappa
  );

  event TokenRedeemAndSwap(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  );

  event TokenRedeemAndRemove(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 swapTokenIndex,
    uint256 swapMinAmount,
    uint256 swapDeadline
  );

  event TokenWithdrawAndRemove(
    address indexed to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    uint8 swapTokenIndex,
    uint256 swapMinAmount,
    uint256 swapDeadline,
    bool swapSuccess,
    bytes32 indexed kappa
  );
}
