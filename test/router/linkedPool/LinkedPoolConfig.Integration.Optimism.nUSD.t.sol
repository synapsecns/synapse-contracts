// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolConfigIntegrationTest} from "./LinkedPoolConfigIntegration.sol";
import {ISynth} from "../../interfaces/ISynth.sol";

contract LinkedPoolConfigNUSDOptTestFork is LinkedPoolConfigIntegrationTest {
    // 2023-11-04
    uint256 public constant OPT_BLOCK_NUMBER = 111750000;

    /// @notice Test swaps worth 10_000 USDC
    uint256 public constant SWAP_VALUE = 10_000;

    /// @notice Used pools have accurate quoting functions, so should have no delta
    uint256 public constant MAX_PERCENT_DELTA = 0;

    /// @notice Optimism sUSD
    address public constant SUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;

    constructor()
        LinkedPoolConfigIntegrationTest("optimism", OPT_BLOCK_NUMBER, "nUSD", SWAP_VALUE, MAX_PERCENT_DELTA)
    {}

    /// @dev sUSD requires special logic for deal cheatcode to work, as the balances are stored externally
    function setBalance(address token, uint256 amount) internal virtual override {
        if (token == SUSD) {
            token = ISynth(SUSD).target().tokenState();
        }
        super.setBalance(token, amount);
    }
}
