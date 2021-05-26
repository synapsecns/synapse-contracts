// contracts/ERC20Deposit.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


contract ERC20Deposit is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    function initialize(
    ) public initializer {
        // "constructor" code...
    }
    
    event TokenDeposit(address from, address to, IERC20 token, uint256 amount);
    event TokenWithdraw(address to, IERC20 token, uint256 amount);

    function deposit(address to, IERC20 token, uint256 amount) {
       token.safeTransferFrom(msg.sender, address(this), amount);
       emit TokenDeposit(msg.sender, to, token, amount);
    }

    function withdraw(address to, IERC20 token, uint256 amount) onlyOwner() {
        token.safeTransferFrom(address(this), to, amount);
        emit TokenWithdraw(to, token, amount);
    }
}
