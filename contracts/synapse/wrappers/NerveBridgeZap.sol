// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/ISwap.sol';
import '../interfaces/ISynapseBridge.sol';

contract NerveBridgeZap {
  using SafeERC20 for IERC20;

  ISwap baseSwap;
  ISynapseBridge synapseBridge;
  IERC20[] public baseTokens;
  uint256 constant MAX_UINT256 = 2**256 - 1;

  constructor(ISwap _baseSwap, ISynapseBridge _synapseBridge) public {
    baseSwap = _baseSwap;
    synapseBridge = _synapseBridge;
    {
      uint8 i;
      for (; i < 32; i++) {
        try _baseSwap.getToken(i) returns (IERC20 token) {
          baseTokens.push(token);
          token.safeApprove(address(_baseSwap), MAX_UINT256);
        } catch {
          break;
        }
      }
      require(i > 1, 'baseSwap must have at least 2 tokens');
    }
  }

  function zapAndDeposit(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256[] calldata liquidityAmounts,
    uint256 minToMint,
    uint256 deadline
  ) public {
    // add liquidity
    for (uint256 i = 0; i < baseTokens.length; i++) {
      if (liquidityAmounts[i] != 0) {
        baseTokens[i].safeTransferFrom(
          msg.sender,
          address(this),
          liquidityAmounts[i]
        );
      }
    }

    uint256 liqAdded = baseSwap.addLiquidity(
      liquidityAmounts,
      minToMint,
      deadline
    );
    // deposit into bridge, gets nUSD
    if (token.allowance(address(this), address(synapseBridge)) < liqAdded) {
      token.safeApprove(address(synapseBridge), MAX_UINT256);
    }
    synapseBridge.deposit(to, chainId, token, liqAdded);
  }

  function zapAndDepositAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256[] calldata liquidityAmounts,
    uint256 minToMint,
    uint256 liqDeadline,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 swapDeadline
  ) public {
    // add liquidity
    for (uint256 i = 0; i < baseTokens.length; i++) {
      if (liquidityAmounts[i] != 0) {
        baseTokens[i].safeTransferFrom(
          msg.sender,
          address(this),
          liquidityAmounts[i]
        );
      }
    }

    uint256 liqAdded = baseSwap.addLiquidity(
      liquidityAmounts,
      minToMint,
      liqDeadline
    );
    // deposit into bridge, bridge attemps to swap into desired asset
    if (token.allowance(address(this), address(synapseBridge)) < liqAdded) {
      token.safeApprove(address(synapseBridge), MAX_UINT256);
    }
    synapseBridge.depositAndSwap(
      to,
      chainId,
      token,
      liqAdded,
      tokenIndexFrom,
      tokenIndexTo,
      minDy,
      swapDeadline
    );
  }
}
