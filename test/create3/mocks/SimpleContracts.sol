// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract SimpleContract {
    constructor() payable {}
}

contract SimpleArgContract {
    uint256 public arg;

    constructor(uint256 arg_) {
        arg = arg_;
    }
}
