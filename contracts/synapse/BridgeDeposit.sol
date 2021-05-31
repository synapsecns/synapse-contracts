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

    function deposit(address to, uint256 chainId, IERC20 token, uint256 amount) public {
       token.safeTransferFrom(msg.sender, address(this), amount);
       emit TokenDeposit(msg.sender, to, chainId, token, amount);
    }
    
    function redeem(address to, uint256 chainId, ERC20Burnable token, uint256 amount) public {
        token.burnFrom(msg.sender, amount);
        emit TokenRedeem(to, chainId, token, amount);
    }

    function withdraw(address to, IERC20 token, uint256 amount) public {
        require(hasRole(NODEGROUP_ROLE, msg.sender), "Caller is not a node group");
        token.safeTransferFrom(address(this), to, amount);
        emit TokenWithdraw(to, token, amount);
    }
}
