// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IOwnable {
    function transferOwnership(address newOwner) external;

    function owner() external view returns (address);
}
