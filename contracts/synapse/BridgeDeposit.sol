// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";


contract BridgeDeposit is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    bytes32 public constant NODEGROUP_ROLE = keccak256("NODEGROUP_ROLE");
    
    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
    }
    
    event TokenDeposit(address from, address to, uint256 chainId, IERC20 token, uint256 amount);
    event TokenRedeem(address to, uint256 chainId, IERC20 token, uint256 amount);
    event TokenWithdraw(address to, IERC20 token, uint256 amount);

    /**
    @notice Relays to nodes to transfers the underlying chain gas token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
    function depositETH(address to, uint256 chainId, uint256 amount) public payable {
        require(msg.value == amount);
        emit TokenDeposit(msg.sender, to, chainId, IERC20(address(0)), amount);
    }

    /**
    @notice Relays to nodes to transfers an ERC20 token cross-chain
    @param to address on other chain to bridge assets to
    @param chainId which chain to bridge assets onto
    @param token ERC20 compatible token to deposit into the bridge
    @param amount Amount in native token decimals to transfer cross-chain pre-fees
    **/
    function deposit(address to, uint256 chainId, IERC20 token, uint256 amount) public {
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
    function redeem(address to, uint256 chainId, ERC20Burnable token, uint256 amount) public {
        token.burnFrom(msg.sender, amount);
        emit TokenRedeem(to, chainId, token, amount);
    }
    
    /**
    @notice Function to be called by the node group to withdraw the underlying assets from the contract
    @param to address on chain to send underlying assets to
    @param token ERC20 compatible token to withdraw from the bridge
    @param amount Amount in native token decimals to withdraw
    **/
    function withdraw(address to, IERC20 token, uint256 amount) public {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Caller is not a node group");
        token.safeTransferFrom(address(this), to, amount);
        emit TokenWithdraw(to, token, amount);
    }

    /**
    @notice Function to be called by the node group to withdraw the underlying gas asset from the contract
    @param to address on chain to send gas asset to
    @param amount Amount in gas token decimals to withdraw
    **/
    function withdrawETH(address payable to, uint256 amount) public {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Caller is not a node group");
        to.transfer(amount);
        emit TokenWithdraw(to, IERC20(address(0)), amount);
    }
}
