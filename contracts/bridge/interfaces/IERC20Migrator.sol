// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IERC20Migrator {
    function migrate(uint256 amount) external;
}
