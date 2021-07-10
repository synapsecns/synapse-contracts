// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/IMetaSwapDeposit.sol';
import '../interfaces/ISynapseBridge.sol';

contract NerveMetaBridgeZap {
  using SafeERC20 for IERC20;

  IMetaSwapDeposit metaSwap;
  ISynapseBridge synapseBridge;
  IERC20[] public metaTokens;
  uint256 constant MAX_UINT256 = 2**256 - 1;

  constructor(IMetaSwapDeposit _metaSwap, ISynapseBridge _synapseBridge)
    public
  {
    metaSwap = _metaSwap;
    synapseBridge = _synapseBridge;
    {
      uint8 i;
      for (; i < 32; i++) {
        try _metaSwap.getToken(i) returns (IERC20 token) {
          metaTokens.push(token);
          token.safeApprove(address(_metaSwap), MAX_UINT256);
        } catch {
          break;
        }
      }
      require(i > 1, 'metaSwap must have at least 2 tokens');
    }
  }

  function swapAndRedeem(
    address to,
    uint256 chainId,
    IERC20 token,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) public {
    metaTokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
    // swap

    uint256 swappedAmount = metaSwap.swap(
      tokenIndexFrom,
      tokenIndexTo,
      dx,
      minDy,
      deadline
    );
    // deposit into bridge, gets nUSD
    if (
      token.allowance(address(this), address(synapseBridge)) < swappedAmount
    ) {
      token.safeApprove(address(synapseBridge), MAX_UINT256);
    }
    synapseBridge.redeem(to, chainId, token, swappedAmount);
  }

  function swapAndRedeemAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline,
    uint8 swapTokenIndex,
    uint256 swapMinAmount,
    uint256 swapDeadline
  ) public {
    metaTokens[tokenIndexFrom].safeTransferFrom(msg.sender, address(this), dx);
    // swap

    uint256 swappedAmount = metaSwap.swap(
      tokenIndexFrom,
      tokenIndexTo,
      dx,
      minDy,
      deadline
    );
    // deposit into bridge, gets nUSD
    if (
      token.allowance(address(this), address(synapseBridge)) < swappedAmount
    ) {
      token.safeApprove(address(synapseBridge), MAX_UINT256);
    }
    synapseBridge.redeemAndSwap(
      to,
      chainId,
      token,
      swappedAmount,
      swappedAmount,
      swapTokenIndex,
      swapMinAmount,
      swapDeadline
    );
  }
}
