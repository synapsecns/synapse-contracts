// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolConfigIntegrationTest} from "./LinkedPoolConfigIntegration.sol";

contract LinkedPoolConfigUSDCBaseTestFork is LinkedPoolConfigIntegrationTest {
    /// @notice Test swaps worth 10_000 USDC
    uint256 public constant SWAP_VALUE = 10_000;

    /// @notice Used pools have accurate quoting functions, so should have no delta
    uint256 public constant MAX_PERCENT_DELTA = 0;

    constructor() LinkedPoolConfigIntegrationTest("base", "CCTP.USDC", SWAP_VALUE, MAX_PERCENT_DELTA) {}
}
