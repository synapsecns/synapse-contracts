// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './interfaces/ISwap.sol';
import './interfaces/IWETH9.sol';

interface IERC20Mintable is IERC20 {
  function mint(address to, uint256 amount) external;
}

contract SynapseBridge is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC20Mintable;
  using SafeMath for uint256;

  bytes32 public constant NODEGROUP_ROLE = keccak256('NODEGROUP_ROLE');
  bytes32 public constant GOVERNANCE_ROLE = keccak256('GOVERNANCE_ROLE');

  mapping(address => uint256) private fees;

  uint256 public startBlockNumber;
  uint256 public constant bridgeVersion = 6;
  uint256 public chainGasAmount;
  address payable public WETH_ADDRESS;
  address public ROUTER;

  mapping(bytes32 => bool) private kappaMap;

  receive() external payable {}
  
  function initialize() external initializer {
    startBlockNumber = block.number;
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    __AccessControl_init();
  }

  function setChainGasAmount(uint256 amount) external {
    require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
    chainGasAmount = amount;
  }

  function setWethAddress(address payable _wethAddress) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
    WETH_ADDRESS = _wethAddress;
  }

  function addKappas(bytes32[] calldata kappas) external {
    require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
    for (uint256 i = 0; i < kappas.length; ++i) {
      kappaMap[kappas[i]] = true;
    }
  }

  function setRouterAddress(address _router) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
    ROUTER = _router;
  }


  event TokenDeposit(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  );
  event TokenRedeem(address indexed to, uint256 chainId, IERC20 token, uint256 amount);
  event TokenWithdraw(address indexed to, IERC20 token, uint256 amount, uint256 fee, bytes32 indexed kappa);
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
    bytes routeraction
  );
  event TokenMintAndSwap(
    address indexed to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    bytes routeraction,
    bool swapSuccess,
    bytes32 indexed kappa
  );
  event TokenRedeemAndSwap(
    address indexed to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    bytes routeraction
  );
  event TokenWithdrawAndSwap(
    address indexed to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    bytes routeraction,
    bool swapSuccess,
    bytes32 indexed kappa
  );

  // VIEW FUNCTIONS ***/
  function getFeeBalance(address tokenAddress) external view returns (uint256) {
    return fees[tokenAddress];
  }

  function kappaExists(bytes32 kappa) external view returns (bool) {
    return kappaMap[kappa];
  }

  // FEE FUNCTIONS ***/
  /**
   * * @notice withdraw specified ERC20 token fees to a given address
   * * @param token ERC20 token in which fees acccumulated to transfer
   * * @param to Address to send the fees to
   */
  function withdrawFees(IERC20 token, address to) external whenNotPaused() {
    require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
    require(to != address(0), "Address is 0x000");
    if (fees[address(token)] != 0) {
      token.safeTransfer(to, fees[address(token)]);
      fees[address(token)] = 0;
    }
  }

  // PAUSABLE FUNCTIONS ***/
  function pause() external {
    require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
    _pause();
  }

  function unpause() external {
    require(hasRole(GOVERNANCE_ROLE, msg.sender), "Not governance");
    _unpause();
  }


  /**
   * @notice Relays to nodes to transfers an ERC20 token cross-chain
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
  ) external nonReentrant() whenNotPaused() {
    emit TokenDeposit(to, chainId, token, amount);
    token.safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @notice Relays to nodes to transfers an ERC20 token cross-chain
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   **/
  function depositMax(
    address to,
    uint256 chainId,
    IERC20 token
  ) external nonReentrant() whenNotPaused() {
    uint256 allowance = token.allowance(msg.sender, address(this));
    uint256 tokenBalance = token.balanceOf(msg.sender);
    uint256 amount = (allowance > tokenBalance) ? tokenBalance : allowance;
    emit TokenDeposit(to, chainId, token, amount);
    token.safeTransferFrom(msg.sender, address(this), amount);
  }


  /**
   * @notice Relays to nodes to both transfer an ERC20 token cross-chain, and then have the nodes execute a swap through a liquidity pool on behalf of the user.
   * @param to address on other chain to bridge assets to
   * @param chainId which chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param routeraction tx data to call router with on dest chain
   **/
  function depositMaxAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    bytes calldata routeraction
  ) external nonReentrant() whenNotPaused() {
    uint256 allowance = token.allowance(msg.sender, address(this));
    uint256 tokenBalance = token.balanceOf(msg.sender);
    uint256 amount = (allowance > tokenBalance) ? tokenBalance : allowance;
     emit TokenDepositAndSwap(
      to,
      chainId,
      token,
      amount,
      routeraction
    );
    token.safeTransferFrom(msg.sender, address(this), amount);
  }


  /**
   * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain pre-fees
   **/
  function redeem(
    address to,
    uint256 chainId,
    ERC20Burnable token,
    uint256 amount
  ) external nonReentrant() whenNotPaused() {
    emit TokenRedeem(to, chainId, token, amount);
    token.burnFrom(msg.sender, amount);
  }

  /**
   * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   **/
    function redeemMax(
    address to,
    uint256 chainId,
    ERC20Burnable token
  ) external nonReentrant() whenNotPaused() {
    uint256 allowance = token.allowance(msg.sender, address(this));
    uint256 tokenBalance = token.balanceOf(msg.sender);
    uint256 amount = (allowance > tokenBalance) ? tokenBalance : allowance;
    emit TokenRedeem(to, chainId, token, amount);
    token.burnFrom(msg.sender, amount);
  }

  /**
   * @notice Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain
   * @param to address on other chain to redeem underlying assets to
   * @param chainId which underlying chain to bridge assets onto
   * @param token ERC20 compatible token to deposit into the bridge
   **/
    function redeemMaxAndSwap(
    address to,
    uint256 chainId,
    ERC20Burnable token,
    bytes calldata routeraction
  ) external nonReentrant() whenNotPaused() {
    uint256 allowance = token.allowance(msg.sender, address(this));
    uint256 tokenBalance = token.balanceOf(msg.sender);
    uint256 amount = (allowance > tokenBalance) ? tokenBalance : allowance;
    emit TokenRedeemAndSwap(to, chainId, token, amount, routeraction);
    token.burnFrom(msg.sender, amount);
  }


  /**
   * @notice Function to be called by the node group to withdraw the underlying assets from the contract
   * @param to address on chain to send underlying assets to
   * @param token ERC20 compatible token to withdraw from the bridge
   * @param amount Amount in native token decimals to withdraw
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param kappa kappa
   **/
  function withdraw(
    address to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    bytes32 kappa
  ) external nonReentrant() whenNotPaused() {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    require(amount > fee, 'Amount must be greater than fee');
    require(!kappaMap[kappa], 'Kappa is already present');
    kappaMap[kappa] = true;
    fees[address(token)] = fees[address(token)].add(fee);
    if (address(token) == WETH_ADDRESS && WETH_ADDRESS != address(0)) {
      IWETH9(WETH_ADDRESS).withdraw(amount.sub(fee));
      (bool success, ) = to.call{value: amount.sub(fee)}("");
      require(success, "ETH_TRANSFER_FAILED");
      emit TokenWithdraw(to, token, amount, fee, kappa);
    } else {
      emit TokenWithdraw(to, token, amount, fee, kappa);
      token.safeTransfer(to, amount.sub(fee));
    }
  }


  /**
   * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to). This is called by the nodes after a TokenDeposit event is emitted.
   * @dev This means the SynapseBridge.sol contract must have minter access to the token attempting to be minted
   * @param to address on other chain to redeem underlying assets to
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain post-fees
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param kappa kappa
   **/
  function mint(
    address payable to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    bytes32 kappa
  ) external nonReentrant() whenNotPaused() {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    require(amount > fee, 'Amount must be greater than fee');
    require(!kappaMap[kappa], 'Kappa is already present');
    kappaMap[kappa] = true;
    fees[address(token)] = fees[address(token)].add(fee);
    emit TokenMint(to, token, amount.sub(fee), fee, kappa);
    token.mint(address(this), amount);
    IERC20(token).safeTransfer(to, amount.sub(fee));
    if (chainGasAmount != 0 && address(this).balance > chainGasAmount) {
      to.call.value(chainGasAmount)("");
    }
  }

  /**
   * @notice Nodes call this function to mint a SynERC20 (or any asset that the bridge is given minter access to), and then attempt to swap the SynERC20 into the desired destination asset. This is called by the nodes after a TokenDepositAndSwap event is emitted.
   * @dev This means the BridgeDeposit.sol contract must have minter access to the token attempting to be minted
   * @param to address on other chain to redeem underlying assets to
   * @param token ERC20 compatible token to deposit into the bridge
   * @param amount Amount in native token decimals to transfer cross-chain post-fees
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param routeraction calldata from origin transaction to call router with
   * @param kappa kappa
   **/
  function mintAndSwap(
    address payable to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    bytes calldata routeraction,
    bytes32 kappa
  ) external nonReentrant() whenNotPaused() {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    require(amount > fee, 'Amount must be greater than fee');
    require(!kappaMap[kappa], 'Kappa is already present');
    kappaMap[kappa] = true;
    fees[address(token)] = fees[address(token)].add(fee);
    // Transfer gas airdrop
    if (chainGasAmount != 0 && address(this).balance > chainGasAmount) {
      to.call.value(chainGasAmount)("");
    }
    token.mint(address(this), amount);
    token.safeIncreaseAllowance(address(ROUTER), amount);
    (bool success, bytes memory result) = ROUTER.call(routeraction);
    if (success) {  
      // Swap successful
      emit TokenMintAndSwap(to, token, amount.sub(fee), fee, routeraction, true, kappa);
    } else {
      IERC20(token).safeTransfer(to, amount.sub(fee));
      emit TokenMintAndSwap(to, token, amount.sub(fee), fee, routeraction, false, kappa);
    }
  }

  /**
   * @notice Function to be called by the node group to withdraw the underlying assets from the contract
   * @param to address on chain to send underlying assets to
   * @param token ERC20 compatible token to withdraw from the bridge
   * @param amount Amount in native token decimals to withdraw
   * @param fee Amount in native token decimals to save to the contract as fees
   * @param routeraction calldata
   * @param kappa kappa
   **/
  function withdrawAndSwap(
    address to,
    IERC20 token,
    uint256 amount,
    uint256 fee,
    bytes calldata routeraction,
    bytes32 kappa
  ) external nonReentrant() whenNotPaused() {
    require(hasRole(NODEGROUP_ROLE, msg.sender), 'Caller is not a node group');
    require(amount > fee, 'Amount must be greater than fee');
    require(!kappaMap[kappa], 'Kappa is already present');
    kappaMap[kappa] = true;
    fees[address(token)] = fees[address(token)].add(fee);

    token.safeIncreaseAllowance(ROUTER, amount.sub(fee));

    (bool success, bytes memory result) = ROUTER.call(routeraction);
    if (success) { 
      // Swap successful
      emit TokenWithdrawAndSwap(to, token, amount.sub(fee), fee, routeraction, true, kappa);
    } else {
      IERC20(token).safeTransfer(to, amount.sub(fee));
      emit TokenWithdrawAndSwap(to, token, amount.sub(fee), fee, routeraction, false, kappa);
    }
  }
}
