// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolConfigIntegrationTest} from "./LinkedPoolConfigIntegration.sol";

contract LinkedPoolConfigUSDCEthTestFork is LinkedPoolConfigIntegrationTest {
    // 2023-11-07
    uint256 public constant ETH_BLOCK_NUMBER = 18521000;

    /// @notice Test swaps worth 10_000 USDC
    uint256 public constant SWAP_VALUE = 10_000;

    /// @notice Used pools have accurate quoting functions, so should have no delta
    uint256 public constant MAX_PERCENT_DELTA = 0;

    constructor()
        LinkedPoolConfigIntegrationTest("mainnet", ETH_BLOCK_NUMBER, "CCTP.USDC", SWAP_VALUE, MAX_PERCENT_DELTA)
    {}
}
