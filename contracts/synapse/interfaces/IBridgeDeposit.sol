// SPDX-License-Identifier: ISC


pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IBridgeDeposit {
    using SafeERC20 for IERC20;
    
    function deposit(address to, uint256 chainId, IERC20 token, uint256 amount) external;
}
