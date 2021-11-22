// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}