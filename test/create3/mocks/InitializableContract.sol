// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract InitializableContract {
    uint256 public value;

    constructor() payable {}

    function setValue(uint256 value_) external {
        value = value_;
    }
}
