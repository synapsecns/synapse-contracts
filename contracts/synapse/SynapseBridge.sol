// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import './interfaces/IMetaSwapDeposit.sol';
import './interfaces/ISwap.sol';

interface IERC20Mintable is IERC20 {
  function mint(address to, uint256 amount) external;

  function mintMultiple(
    address to,
    uint256 amount,
    address feeAddress,
    uint256 feeAmount
  ) external;
}

contract SynapseBridge is Initializable, AccessControlUpgradeable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  bytes32 public constant NODEGROUP_ROLE = keccak256('NODEGROUP_ROLE');

  mapping(address => uint256) private fees;
  uint256 private ethFees;

  uint256 public startBlockNumber;

  function initialize() public initializer {
    startBlockNumber = block.number;
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    __AccessControl_init();
  }

  event TokenDeposit(
    address from,
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  );
  event TokenRedeem(address to, uint256 chainId, IERC20 token, uint256 amount);
  event TokenWithdraw(address to, IERC20 token, uint256 amount, uint256 fee);
  event TokenMint(
    address to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee
  );
  event TokenDepositAndSwap(
    address from,
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  );
  event TokenMintAndSwap(
    address to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    bool swapSuccess
  );
  event TokenRedeemAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint256 swapTokenAmount,
    uint8 swapTokenIndex,
    uint256 swapMinAmount,
    uint256 swapDeadline
  );
  event TokenWithdrawAndRemove(
    address to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    bool swapSuccess
  );

  // VIEW FUNCTIONS ***/
  function getFeeBalance(address tokenAddress) external view returns (uint256) {
    return fees[tokenAddress];
  }

  function getETHFeeBalance() external view returns (uint256) {
    return ethFees;
  }

  // FEE FUNCTIONS ***/
  /**
   * @notice withdraw specified ERC20 token fees to a given address
   * @param token ERC20 token in which fees acccumulated to transfer
   * @param to Address to send the fees to
   */
  function withdrawFees(IERC20 token, address to) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
    if (fees[address(token)] != 0) {
      token.safeTransfer(to, fees[address(token)]);
    }
  }

  /**
   * @notice withdraw gas token fees to a given address
   * @param to Address to send the gas fees to
   */
  function withdrawETHFees(address payable to) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
    if (ethFees != 0) {
      to.transfer(ethFees);
    }
  }

  /**
    @notice Relays to nodes to transfers the underlying chain gas token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
  function depositETH(
    address to,
    uint256 chainId,
    uint256 amount
  ) public payable {
    require(msg.value == amount, "Value doesn't match amount");
    emit TokenDeposit(msg.sender, to, chainId, IERC20(address(0)), amount);
  }

  /**
    @notice Relays to nodes to transfers an ERC20 token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
  function deposit(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) public {
    token.safeTransferFrom(msg.sender, address(this), amount);
    emit TokenDeposit(msg.sender, to, chainId, token, amount);
  }

  /**
    @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
    @param to address on other chain to redeem underlying assets to
    @param chainId which underlying chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
  function redeem(
    address to,
    uint256 chainId,
    ERC20Burnable token,
    uint256 amount
  ) public {
    token.burnFrom(msg.sender, amount);
    emit TokenRedeem(to, chainId, token, amount);
  }

  /**
    @notice Function to be called by the node group to withdraw the underlying assets from the contract
    @param to address on chain to send underlying assets to
    @param token ERC20 compatible token to withdraw from the bridge
    @param amount Amount in native token decimals to withdraw
    @param fee Amount in native token decimals to save to the contract as fees
    **/
  function withdraw(
    address to,
    IERC20 token,
    uint256 amount,
    uint256 fee
  ) public {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    fees[address(token)] = fees[address(token)].add(fee);
    token.safeTransfer(to, amount);
    emit TokenWithdraw(to, token, amount, fee);
  }

  /**
    @notice Function to be called by the node group to withdraw the underlying gas asset from the contract
    @param to address on chain to send gas asset to
    @param amount Amount in gas token decimals to withdraw (after subtracting fee already)
    @param fee Amount in gas token decimals to save to the contract as fees
    **/
  function withdrawETH(
    address payable to,
    uint256 amount,
    uint256 fee
  ) public {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    ethFees = ethFees.add(fee);
    to.transfer(amount);
    emit TokenWithdraw(to, IERC20(address(0)), amount, fee);
  }

  /**
    @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.
    @dev This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted
    @param to address on other chain to redeem underlying assets to
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain post-fees
    @param fee Amount in native token decimals to save to the contract as fees
    **/
  function mint(
    address to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee
  ) public {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    fees[address(token)] = fees[address(token)].add(fee);
    token.mint(address(this), amount.add(fee));
    IERC20(token).safeTransfer(to, amount);
    emit TokenMint(to, token, amount, fee);
  }

  /**
    @notice Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    @param tokenIndexFrom the token the user wants to swap from
    @param tokenIndexTo the token the user wants to swap to
    @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
    @param deadline latest timestamp to accept this transaction
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
  ) public {
    token.safeTransferFrom(msg.sender, address(this), amount);
    emit TokenDepositAndSwap(
      msg.sender,
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
    @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
    @param to address on other chain to redeem underlying assets to
    @param chainId which underlying chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    @param swapTokenAmount Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token
    @param swapTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
    @param swapMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
    @param swapDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
    **/
  function redeemAndSwap(
    address to,
    uint256 chainId,
    ERC20Burnable token,
    uint256 amount,
    uint256 swapTokenAmount,
    uint8 swapTokenIndex,
    uint256 swapMinAmount,
    uint256 swapDeadline
  ) public {
    token.burnFrom(msg.sender, amount);
    emit TokenRedeemAndSwap(
      to,
      chainId,
      token,
      amount,
      swapTokenAmount,
      swapTokenIndex,
      swapMinAmount,
      swapDeadline
    );
  }

  /**
    @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.
    @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
    @param to address on other chain to redeem underlying assets to
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain post-fees
    @param fee Amount in native token decimals to save to the contract as fees
    @param pool Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.
    @param tokenIndexFrom Index of the SynERC20 asset in the pool
    @param tokenIndexTo Index of the desired final asset
    @param minDy Minumum amount (in final asset decimals) that must be swapped for, otherwise the user will receive the SynERC20.
    @param deadline Epoch time of the deadline that the swap is allowed to be executed. 
    **/
  function mintAndSwap(
    address to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    IMetaSwapDeposit pool,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) public {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    fees[address(token)] = fees[address(token)].add(fee);
    // first check to make sure more will be given than min amount required
    uint256 expectedOutput = IMetaSwapDeposit(pool).calculateSwap(
      tokenIndexFrom,
      tokenIndexTo,
      amount
    );

    if (expectedOutput >= minDy) {
      // proceed with swap
      token.mint(address(this), amount.add(fee));
      token.approve(address(pool), amount);
      try
        IMetaSwapDeposit(pool).swap(
          tokenIndexFrom,
          tokenIndexTo,
          amount,
          minDy,
          deadline
        )
      returns (uint256 finalSwappedAmount) {
        // Swap succeeded, transfer swapped asset
        IERC20 swappedTokenTo = IMetaSwapDeposit(pool).getToken(tokenIndexTo);
        swappedTokenTo.safeTransfer(to, finalSwappedAmount);
        emit TokenMintAndSwap(to, token, amount, fee, true);
      } catch {
        IERC20(token).safeTransfer(to, amount);
        emit TokenMintAndSwap(to, token, amount, fee, false);
      }
    } else {
      token.mint(address(this), amount.add(fee));
      IERC20(token).safeTransfer(to, amount);
      emit TokenMintAndSwap(to, token, amount, fee, false);
    }
  }

  /**
    @notice Function to be called by the node group to withdraw the underlying assets from the contract
    @param to address on chain to send underlying assets to
    @param token ERC20 compatible token to withdraw from the bridge
    @param amount Amount in native token decimals to withdraw
    @param fee Amount in native token decimals to save to the contract as fees
    @param pool Destination chain's pool to use to swap SynERC20 -> Asset. The nodes determine this by using PoolConfig.sol.
    @param swapTokenAmount Amount of (typically) LP token to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token
    @param swapTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
    @param swapMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
    @param swapDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
    **/
  function withdrawAndRemove(
    address to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    ISwap pool,
    uint256 swapTokenAmount,
    uint8 swapTokenIndex,
    uint256 swapMinAmount,
    uint256 swapDeadline
  ) public {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    fees[address(token)] = fees[address(token)].add(fee);
    // first check to make sure more will be given than min amount required

    uint256 expectedOutput = ISwap(pool).calculateRemoveLiquidityOneToken(
      swapTokenAmount,
      swapTokenIndex
    );

    if (expectedOutput >= swapMinAmount) {
      token.safeApprove(address(pool), swapTokenAmount);
      try
        ISwap(pool).removeLiquidityOneToken(
          swapTokenAmount,
          swapTokenIndex,
          swapMinAmount,
          swapDeadline
        )
      returns (uint256 finalSwappedAmount) {
        // Swap succeeded, transfer swapped asset
        IERC20 swappedTokenTo = ISwap(pool).getToken(swapTokenIndex);
        swappedTokenTo.safeTransfer(to, finalSwappedAmount);
        emit TokenWithdrawAndRemove(to, token, amount, fee, true);
      } catch {
        IERC20(token).safeTransfer(to, amount);
        emit TokenWithdrawAndRemove(to, token, amount, fee, false);
      }
    } else {
      token.safeTransfer(to, amount);
      emit TokenWithdrawAndRemove(to, token, amount, fee, false);
    }
  }
}
