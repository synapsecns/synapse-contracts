// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolConfigIntegrationTest} from "./LinkedPoolConfigIntegration.sol";

interface IMintable {
    function mint(address account, uint256 amount) external;
}

contract LinkedPoolConfigNUSDAvaxTestFork is LinkedPoolConfigIntegrationTest {
    /// @notice Test swaps worth 10_000 nUSD
    uint256 public constant SWAP_VALUE = 10_000;

    /// @notice Used pools have accurate quoting functions, so should have no delta
    uint256 public constant MAX_PERCENT_DELTA = 0;

    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address public constant USDC_MINTER = 0x420F5035fd5dC62a167E7e7f08B604335aE272b8;

    constructor() LinkedPoolConfigIntegrationTest("avalanche", "nUSD", SWAP_VALUE, MAX_PERCENT_DELTA) {}

    function setBalance(address token, uint256 amount) internal override {
        if (token == USDC) {
            vm.prank(USDC_MINTER);
            IMintable(USDC).mint(user, amount);
        } else {
            super.setBalance(token, amount);
        }
    }
}
