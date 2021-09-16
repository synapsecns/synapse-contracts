// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/IMetaSwapDeposit.sol';
import '../interfaces/ISynapseBridge.sol';
import "../interfaces/IWETH9.sol";

import {TokenUtils} from "../utils/TokenUtils.sol";

contract NerveMetaBridgeZap {
  using SafeERC20 for IERC20;

  IMetaSwapDeposit metaSwap;
  ISynapseBridge synapseBridge;
  IERC20[] public metaTokens;

  address payable public immutable WETH_ADDRESS;


  uint256 constant MAX_UINT256 = 2**256 - 1;

  constructor(address payable _wethAddress, IMetaSwapDeposit _metaSwap, ISynapseBridge _synapseBridge)
    public
  {
    WETH_ADDRESS = _wethAddress;
    metaSwap = _metaSwap;
    synapseBridge = _synapseBridge;
    {
      uint8 i;
      for (; i < 32; i++) {
        try _metaSwap.getToken(i) returns (IERC20 token) {
          metaTokens.push(token);
          token.safeApprove(address(_metaSwap), MAX_UINT256);
          token.safeApprove(address(synapseBridge), MAX_UINT256);
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
  ) external {
    uint256 swappedAmount = TokenUtils.swapWithApproval(
      to,
      token,
      tokenIndexFrom,
      tokenIndexTo,
      dx,
      minDy,
      deadline,
      metaTokens,
      metaSwap,
      address(synapseBridge)
    );

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
    uint8 swapTokenIndexFrom,
    uint8 swapTokenIndexTo,
    uint256 swapMinDy,
    uint256 swapDeadline
  ) external {
    uint256 swappedAmount = TokenUtils.swapWithApproval(
      to,
      token,
      tokenIndexFrom,
      tokenIndexTo,
      dx,
      minDy,
      deadline,
      metaTokens,
      metaSwap,
      address(synapseBridge)
    );

    synapseBridge.redeemAndSwap(
      to,
      chainId,
      token,
      swappedAmount,
      swapTokenIndexFrom,
      swapTokenIndexTo,
      swapMinDy,
      swapDeadline
    );
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
  ) external {
    uint256 swappedAmount = TokenUtils.swapWithApproval(
      to,
      token,
      tokenIndexFrom,
      tokenIndexTo,
      dx,
      minDy,
      deadline,
      metaTokens,
      metaSwap,
      address(synapseBridge)
    );

    synapseBridge.redeemAndRemove(
      to,
      chainId,
      token,
      swappedAmount,
      liqTokenIndex,
      liqMinAmount,
      liqDeadline
    );
  }

  /**
   * @notice wraps SynapseBridge redeem()
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
  function redeem(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
    ) external {
      TokenUtils.safeTransferWithApprove(token, amount, address(synapseBridge));

      synapseBridge.redeem(to, chainId, token, amount);
  }


  function swapETHAndRedeem(
    address to,
    uint256 chainId,
    IERC20 token,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) external payable {
    require(WETH_ADDRESS != address(0), 'WETH 0');
    require(msg.value > 0 && msg.value == dx, 'INCORRECT MSG VALUE');
    IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
    
    // swap
    uint256 swappedAmount = metaSwap.swap(
      tokenIndexFrom,
      tokenIndexTo,
      dx,
      minDy,
      deadline
    );

    synapseBridge.redeem(to, chainId, token, swappedAmount);
  }

    /**
   * @notice Wraps redeemAndSwap on SynapseBridge.sol
   * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
   * @param deadline latest timestamp to accept this transaction
   **/
  function redeemAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) external {
    TokenUtils.safeTransferWithApprove(token, amount, address(synapseBridge));

    synapseBridge.redeemAndSwap(to, chainId, token, amount, tokenIndexFrom, tokenIndexTo, minDy, deadline);
  }  

   /**
   * @notice Wraps redeemAndRemove on SynapseBridge
   * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token 
   * @param liqTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
   * @param liqMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
   * @param liqDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
   **/
  function redeemAndRemove(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 liqTokenIndex,
    uint256 liqMinAmount,
    uint256 liqDeadline
  ) external {
    TokenUtils.safeTransferWithApprove(token, amount, address(synapseBridge));

    synapseBridge.redeemAndRemove(
      to,
      chainId,
      token,
      amount,
      liqTokenIndex,
      liqMinAmount,
      liqDeadline
    );
  }
}
