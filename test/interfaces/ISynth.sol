// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

/// @notice Interface to enable minting of sUSD in tests
/// @dev Instead of using `deal(sUSD, user, amount)` in tests, use:
/// `deal(ISynth(sUSD).target().tokenState(), user, amount)`
interface ISynth {
    function target() external view returns (ITarget);
}

interface ITarget {
    function tokenState() external view returns (address);
}
