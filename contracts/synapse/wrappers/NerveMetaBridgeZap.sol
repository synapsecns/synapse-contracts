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

  /**
 * @notice Calculate amount of tokens you receive on swap
 * @param tokenIndexFrom the token the user wants to sell
 * @param tokenIndexTo the token the user wants to buy
 * @param dx the amount of tokens the user wants to sell. If the token charges
 * a fee on transfers, use the amount that gets transferred after the fee.
 * @return amount of tokens the user will receive
*/
  function calculateSwap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx
  ) external view virtual returns (uint256) {
    return metaSwap.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
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

  function swapAndRedeemAndRemove(
    address to,
    uint256 chainId,
    IERC20 token,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline,
    uint8 liqTokenIndex,
    uint256 liqMinAmount,
    uint256 liqDeadline
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
    synapseBridge.redeemAndRemove(
      to,
      chainId,
      token,
      swappedAmount,
      swappedAmount,
      liqTokenIndex,
      liqMinAmount,
      liqDeadline
    );
  }
}
