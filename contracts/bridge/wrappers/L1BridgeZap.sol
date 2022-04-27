// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/ISwap.sol';
import '../interfaces/ISynapseBridge.sol';
import "../interfaces/IWETH9.sol";


/**
 * @title L1BridgeZap
 * @notice This contract is responsible for handling user Zaps into the SynapseBridge contract, through the Synapse Swap contracts. It does so
 * It does so by combining the action of addLiquidity() to the base swap pool, and then calling either deposit() or depositAndSwap() on the bridge.
 * This is done in hopes of automating portions of the bridge user experience to users, while keeping the SynapseBridge contract logic small.
 *
 * @dev This contract should be deployed with a base Swap.sol address and a SynapseBridge.sol address, otherwise, it will not function.
 */
contract L1BridgeZap {
  using SafeERC20 for IERC20;

  uint256 constant MAX_UINT256 = 2**256 - 1;
  
  ISwap baseSwap;
  ISynapseBridge synapseBridge;
  IERC20[] public baseTokens;
  address payable public immutable WETH_ADDRESS;
  

  /**
   * @notice Constructs the contract, approves each token inside of baseSwap to be used by baseSwap (needed for addLiquidity())
   */
  constructor(address payable _wethAddress, ISwap _baseSwap, ISynapseBridge _synapseBridge) public {
    WETH_ADDRESS = _wethAddress;
    baseSwap = _baseSwap;
    synapseBridge = _synapseBridge;
    IERC20(_wethAddress).safeIncreaseAllowance(address(_synapseBridge), MAX_UINT256);
    if (address(_baseSwap) != address(0)) {
    {
      uint8 i;
      for (; i < 32; i++) {
        try _baseSwap.getToken(i) returns (IERC20 token) {
          baseTokens.push(token);
          token.safeIncreaseAllowance(address(_baseSwap), MAX_UINT256);
        } catch {
          break;
        }
      }
      require(i > 1, 'baseSwap must have at least 2 tokens');
    }
    }
  }
  
  /**
   * @notice Wraps SynapseBridge deposit() function to make it compatible w/ ETH -> WETH conversions
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
  function depositETH(
    address to,
    uint256 chainId,
    uint256 amount
    ) external payable {
      require(msg.value > 0 && msg.value == amount, 'INCORRECT MSG VALUE');
      IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
      synapseBridge.deposit(to, chainId, IERC20(WETH_ADDRESS), amount);
    }

  /**
   * @notice Wraps SynapseBridge depositAndSwap() function to make it compatible w/ ETH -> WETH conversions
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
   * @param deadline latest timestamp to accept this transaction
   **/
  function depositETHAndSwap(
    address to,
    uint256 chainId,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
    ) external payable {
      require(msg.value > 0 && msg.value == amount, 'INCORRECT MSG VALUE');
      IWETH9(WETH_ADDRESS).deposit{value: msg.value}();
      synapseBridge.depositAndSwap(to, chainId, IERC20(WETH_ADDRESS), amount, tokenIndexFrom, tokenIndexTo, minDy, deadline);
    }


  /**
   * @notice A simple method to calculate prices from deposits or
   * withdrawals, excluding fees but including slippage. This is
   * helpful as an input into the various "min" parameters on calls
   * to fight front-running
   *
   * @dev This shouldn't be used outside frontends for user estimates.
   *
   * @param amounts an array of token amounts to deposit or withdrawal,
   * corresponding to pooledTokens. The amount should be in each
   * pooled token's native precision.
   * @param deposit whether this is a deposit or a withdrawal
   * @return token amount the user will receive
   */
  function calculateTokenAmount(uint256[] calldata amounts, bool deposit)
    external
    view
    virtual
    returns (uint256)
  {
    return baseSwap.calculateTokenAmount(amounts, deposit);
  }

      /**
     * @notice Calculate the amount of underlying token available to withdraw
     * when withdrawing via only single token
     * @param tokenAmount the amount of LP token to burn
     * @param tokenIndex index of which token will be withdrawn
     * @return availableTokenAmount calculated amount of underlying token
     * available to withdraw
     */
    function calculateRemoveLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view virtual returns (uint256 availableTokenAmount) {
        return baseSwap.calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
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
  ) external {
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
  ) external {
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

    /**
   * @notice Wraps SynapseBridge deposit() function
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
  function deposit(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
    ) external {
      token.safeTransferFrom(msg.sender, address(this), amount);

      if (token.allowance(address(this), address(synapseBridge)) < amount) {
        token.safeApprove(address(synapseBridge), MAX_UINT256);
      }
      synapseBridge.deposit(to, chainId, token, amount);
  }
  
  /**
   * @notice Wraps SynapseBridge depositAndSwap() function
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
   * @param deadline latest timestamp to accept this transaction
   **/
  function depositAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) external {
      token.safeTransferFrom(msg.sender, address(this), amount);
      
      if (token.allowance(address(this), address(synapseBridge)) < amount) {
        token.safeApprove(address(synapseBridge), MAX_UINT256);
      }
      synapseBridge.depositAndSwap(to, chainId, token, amount, tokenIndexFrom, tokenIndexTo, minDy, deadline);
  }


    /**
   * @notice Wraps SynapseBridge redeem() function
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to redeem into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
  function redeem(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
    ) external {
      token.safeTransferFrom(msg.sender, address(this), amount);

      if (token.allowance(address(this), address(synapseBridge)) < amount) {
        token.safeApprove(address(synapseBridge), MAX_UINT256);
      }
      synapseBridge.redeem(to, chainId, token, amount);
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
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            amount,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline
        );
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
        token.safeTransferFrom(msg.sender, address(this), amount);
        if (token.allowance(address(this), address(synapseBridge)) < amount) {
            token.safeApprove(address(synapseBridge), MAX_UINT256);
        }
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


  /**
   * @notice Wraps SynapseBridge redeemv2() function
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to redeem into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
  function redeemV2(
    bytes32 to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) external {
    token.safeTransferFrom(msg.sender, address(this), amount);

    if (token.allowance(address(this), address(synapseBridge)) < amount) {
      token.safeApprove(address(synapseBridge), MAX_UINT256);
    }
    synapseBridge.redeemV2(to, chainId, token, amount);
  }

}
