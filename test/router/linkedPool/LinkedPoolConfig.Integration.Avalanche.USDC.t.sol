// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolConfigIntegrationTest} from "./LinkedPoolConfigIntegration.sol";

contract LinkedPoolConfigUSDCAvaxTestFork is LinkedPoolConfigIntegrationTest {
    // Don't pin to a specific block number
    uint256 public constant AVAX_BLOCK_NUMBER = 0;

    /// @notice Test swaps worth 10_000 USDC
    uint256 public constant SWAP_VALUE = 10_000;

    /// @notice Used pools have accurate quoting functions, so should have no delta
    uint256 public constant MAX_PERCENT_DELTA = 0;

    constructor()
        LinkedPoolConfigIntegrationTest("avalanche", AVAX_BLOCK_NUMBER, "CCTP.USDC", SWAP_VALUE, MAX_PERCENT_DELTA)
    {}

    // TODO: remote this before merging
    function runIfDeployed() public pure override returns (bool) {
        return true;
    }
}
