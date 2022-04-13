// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Swap.sol";

interface ILendingPool {
  /**
   * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to deposit
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   **/
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);
}

/**
 * @title AaveSwapWrapper
 * @notice A wrapper contract for interacting with aTokens
 */
contract AaveSwapWrapper {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  mapping(uint8 => bool) private isUnderlyingIndex;

  // constants
  uint8 private constant MAX_UINT8 = 2**8 - 1;
  uint256 private constant MAX_UINT256 = 2**256 - 1;

  // immutables
  Swap public immutable SWAP;
  LPToken public immutable LP_TOKEN;
  address public immutable OWNER;
  IERC20[] public POOLED_TOKENS;
  IERC20[] public UNDERLYING_TOKENS;
  ILendingPool public LENDING_POOL;

  constructor(
    Swap swap,
    IERC20[] memory underlyingTokens,
    address lendingPool,
    address owner
  ) public {
    (, , , , , , LPToken lpToken) = swap.swapStorage();
    for (uint8 i = 0; i < MAX_UINT8; i++) {
      try swap.getToken(i) returns (IERC20 token) {
        POOLED_TOKENS.push(token);
        // Approve pooled tokens to be used by Swap
        token.approve(address(swap), MAX_UINT256);
      } catch {
        break;
      }
    }

    for (uint8 i = 0; i < POOLED_TOKENS.length; i++) {
      if (POOLED_TOKENS[i] == underlyingTokens[i]) {
        isUnderlyingIndex[i] = true;
      } else {
        isUnderlyingIndex[i] = false;
        underlyingTokens[i].approve(lendingPool, MAX_UINT256);
      }
    }

    // Set immutable variables
    SWAP = swap;
    LP_TOKEN = lpToken;
    OWNER = owner;
    UNDERLYING_TOKENS = underlyingTokens;
    LENDING_POOL = ILendingPool(lendingPool);

    // Approve LPToken to be used by Swap
    lpToken.approve(address(swap), MAX_UINT256);
  }

  /**
   * @notice Add liquidity to the pool with the given amounts of tokens.
   * @param amounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amount of LP token user minted and received
   */
  function addLiquidity(
    uint256[] memory amounts,
    uint256 minToMint,
    uint256 deadline
  ) external returns (uint256) {
    // Go through amounts array and transfer respective tokens to this contract.
    for (uint8 i = 0; i < amounts.length; i++) {
      uint256 amount = amounts[i];
      if (amount > 0) {
        UNDERLYING_TOKENS[i].safeTransferFrom(
          msg.sender,
          address(this),
          amount
        );
        if (isUnderlyingIndex[i] == false) {
          LENDING_POOL.deposit(
            address(UNDERLYING_TOKENS[i]),
            amount,
            address(this),
            0
          );
        }
      }
    }

    // Add the assets to the pool
    uint256 lpTokenAmount = SWAP.addLiquidity(amounts, minToMint, deadline);
    // Send the LPToken to msg.sender
    IERC20(address(LP_TOKEN)).safeTransfer(msg.sender, lpTokenAmount);
    return lpTokenAmount;
  }

  /**
   * @notice Burn LP tokens to remove liquidity from the pool.
   * @dev Liquidity can always be removed, even when the pool is paused. Caller
   * will receive ETH instead of WETH9.
   * @param amount the amount of LP tokens to burn
   * @param minAmounts the minimum amounts of each token in the pool
   *        acceptable for this burn. Useful as a front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amounts of tokens user received
   */
  function removeLiquidity(
    uint256 amount,
    uint256[] calldata minAmounts,
    uint256 deadline
  ) external returns (uint256[] memory) {
    // Transfer LPToken from msg.sender to this contract.
    IERC20(address(LP_TOKEN)).safeTransferFrom(
      msg.sender,
      address(this),
      amount
    );
    // Remove liquidity
    uint256[] memory amounts = SWAP.removeLiquidity(
      amount,
      minAmounts,
      deadline
    );
    // Send the tokens back to the user
    for (uint8 i = 0; i < amounts.length; i++) {
      if (isUnderlyingIndex[i] == true) {
        UNDERLYING_TOKENS[i].safeTransfer(msg.sender, amounts[i]);
      } else {
        LENDING_POOL.withdraw(
          address(UNDERLYING_TOKENS[i]),
          amounts[i],
          msg.sender
        );
        // underlyingTokens[i].safeTransfer(msg.sender, amounts[i]);
      }
    }
    return amounts;
  }

  /**
   * @notice Remove liquidity from the pool all in one token.
   * @dev Caller will receive ETH instead of WETH9.
   * @param tokenAmount the amount of the token you want to receive
   * @param tokenIndex the index of the token you want to receive
   * @param minAmount the minimum amount to withdraw, otherwise revert
   * @param deadline latest timestamp to accept this transaction
   * @return amount of chosen token user received
   */
  function removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount,
    uint256 deadline
  ) external returns (uint256) {
    // Transfer LPToken from msg.sender to this contract.
    IERC20(address(LP_TOKEN)).safeTransferFrom(
      msg.sender,
      address(this),
      tokenAmount
    );
    // Withdraw via single token
    uint256 amount = SWAP.removeLiquidityOneToken(
      tokenAmount,
      tokenIndex,
      minAmount,
      deadline
    );
    // Transfer the token to msg.sender accordingly
    if (isUnderlyingIndex[tokenIndex] == true) {
      UNDERLYING_TOKENS[tokenIndex].safeTransfer(msg.sender, amount);
    } else {
      LENDING_POOL.withdraw(
        address(UNDERLYING_TOKENS[tokenIndex]),
        amount,
        msg.sender
      );
    }
    return amount;
  }

  /**
   * @notice Swap two tokens using the underlying pool. If tokenIndexFrom
   * represents WETH9 in the pool, the caller must set msg.value equal to dx.
   * If the user is swapping to WETH9 in the pool, the user will receive ETH instead.
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param dx the amount of tokens the user wants to swap from
   * @param minDy the min amount the user would like to receive, or revert.
   * @param deadline latest timestamp to accept this transaction
   */
  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  ) external returns (uint256) {
    // Transfer tokens from msg.sender to this contract
    UNDERLYING_TOKENS[tokenIndexFrom].safeTransferFrom(
      msg.sender,
      address(this),
      dx
    );
    if (isUnderlyingIndex[tokenIndexFrom] == false) {
      LENDING_POOL.deposit(
        address(UNDERLYING_TOKENS[tokenIndexFrom]),
        dx,
        address(this),
        0
      );
    }
    // Execute swap
    uint256 dy = SWAP.swap(tokenIndexFrom, tokenIndexTo, dx, minDy, deadline);
    // Transfer the swapped tokens to msg.sender
    if (isUnderlyingIndex[tokenIndexTo] == false) {
      LENDING_POOL.withdraw(
        address(UNDERLYING_TOKENS[tokenIndexTo]),
        dy,
        msg.sender
      );
    } else {
      UNDERLYING_TOKENS[tokenIndexTo].safeTransfer(msg.sender, dy);
    }
    return dy;
  }

  /**
   * @notice Rescues any of the ETH, the pooled tokens, or the LPToken that may be stuck
   * in this contract. Only the OWNER can call this function.
   */
  function rescue() external {
    require(msg.sender == OWNER, "CALLED_BY_NON_OWNER");
    IERC20[] memory tokens = POOLED_TOKENS;
    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].safeTransfer(msg.sender, tokens[i].balanceOf(address(this)));
    }

    for (uint256 i = 0; i < UNDERLYING_TOKENS.length; i++) {
      UNDERLYING_TOKENS[i].safeTransfer(
        msg.sender,
        UNDERLYING_TOKENS[i].balanceOf(address(this))
      );
    }

    IERC20 lpToken_ = IERC20(address(LP_TOKEN));
    lpToken_.safeTransfer(msg.sender, lpToken_.balanceOf(address(this)));
  }

  // VIEW FUNCTIONS

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
    return SWAP.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
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
   * pooled token's native precision. If a token charges a fee on transfers,
   * use the amount that gets transferred after the fee.
   * @param deposit whether this is a deposit or a withdrawal
   * @return token amount the user will receive
   */
  function calculateTokenAmount(uint256[] calldata amounts, bool deposit)
    external
    view
    returns (uint256)
  {
    return SWAP.calculateTokenAmount(amounts, deposit);
  }

  /**
   * @notice A simple method to calculate amount of each underlying
   * tokens that is returned upon burning given amount of LP tokens
   * @param amount the amount of LP tokens that would be burned on withdrawal
   * @return array of token balances that the user will receive
   */
  function calculateRemoveLiquidity(uint256 amount)
    external
    view
    returns (uint256[] memory)
  {
    return SWAP.calculateRemoveLiquidity(amount);
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
  ) external view returns (uint256 availableTokenAmount) {
    return SWAP.calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
  }

  /**
   * @notice Return address of the pooled token at given index. Reverts if tokenIndex is out of range.
   * @param index the index of the token
   * @return address of the token at given index
   */
  function getToken(uint8 index) public view virtual returns (IERC20) {
    if (index < UNDERLYING_TOKENS.length) {
      return UNDERLYING_TOKENS[index];
    } else {
      revert();
    }
  }
}
