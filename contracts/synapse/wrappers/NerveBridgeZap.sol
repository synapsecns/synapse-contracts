// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/ISwap.sol';
import '../interfaces/ISynapseBridge.sol';

/**
 * @title NerveBridgeZap
 * @notice This contract is responsible for handling user Zaps into the SynapseBridge contract, through the Nerve Swap contracts. It does so
 * It does so by combining the action of addLiquidity() to the base swap pool, and then calling either deposit() or depositAndSwap() on the bridge.
 * This is done in hopes of automating portions of the bridge user experience to users, while keeping the SynapseBridge contract logic small.
 *
 * @dev This contract should be deployed with a base Swap.sol address and a SynapseBridge.sol address, otherwise, it will not function.
 */
contract NerveBridgeZap {
  using SafeERC20 for IERC20;

  ISwap baseSwap;
  ISynapseBridge synapseBridge;
  IERC20[] public baseTokens;
  uint256 constant MAX_UINT256 = 2**256 - 1;

  // Constructs the contract, approves each token inside of baseSwap to be used by baseSwap (needed for addLiquidity())
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

  /**
   * @notice Combines adding liquidity to the given Swap, and calls deposit() on the bridge using that LP token
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param liquidityAmounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   **/
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

  /**
   * @notice Combines adding liquidity to the given Swap, and calls depositAndSwap() on the bridge using that LP token
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param liquidityAmounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * @param liqDeadline latest timestamp to accept this transaction
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
   * @param swapDeadline latest timestamp to accept this transaction
   **/
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
