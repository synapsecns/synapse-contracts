// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IOwnable {
    /// @notice Returns the address of the current owner.
    function owner() external view returns (address);
}
