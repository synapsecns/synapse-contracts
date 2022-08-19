// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

/**
 * @dev Interface of Inventory Items.
 */
interface IInventoryItem is IERC20 {
    /**
     * @dev Burns tokens.
     */
    function burnFrom(address from, uint256 amount) external;

    function mint(address to, uint256 amount) external;
}