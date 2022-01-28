// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IERC20} from "@openzeppelin/contracts-4.4.2/token/ERC20/IERC20.sol";


interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}
