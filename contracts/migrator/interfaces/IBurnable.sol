// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBurnable {
    function burnFrom(address from, uint256 amount) external;
}
