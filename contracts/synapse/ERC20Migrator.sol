// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/**
 * @title ERC20Migrator
 * @dev This contract can be used to migrate an ERC20 token from one
 * contract to another, where each token holder has to opt-in to the migration.
 * To opt-in, users must approve for this contract the number of tokens they
 * want to migrate. Once the allowance is set up, anyone can trigger the
 * migration to the new token contract. In this way, token holders "turn in"
 * their old balance and will be minted an equal amount in the new token.
 * The new token contract must be mintable.
 * ```
 */


interface IERC20Mintable is IERC20 {
  function mint(address to, uint256 amount) external;
}

contract ERC20Migrator {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  // Address of the old token contract
  IERC20 private _legacyToken;

  // Address of the new token contract
  IERC20Mintable private _newToken;
  
  /**
   * @param legacyToken address of the old token contract
   */
  constructor(IERC20 legacyToken, IERC20Mintable newToken) public {
    _legacyToken = legacyToken;
    _newToken = newToken;
  }

  /**
   * @dev Returns the legacy token that is being migrated.
   */
  function legacyToken() external view returns (IERC20) {
    return _legacyToken;
  }

  /**
   * @dev Returns the new token to which we are migrating.
   */
  function newToken() external view returns (IERC20) {
    return _newToken;
  }

  /**
   * @dev Transfers part of an account's balance in the old token to this
   * contract, and mints the same amount of new tokens for that account.
   * @param amount amount of tokens to be migrated
   */
  function migrate(uint256 amount) external {
    _legacyToken.safeTransferFrom(msg.sender, address(this), amount);
    uint256 amountToMint = amount.mul(5).div(2);
    _newToken.mint(msg.sender, amountToMint);
  }
}