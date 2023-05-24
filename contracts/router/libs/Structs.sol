// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Struct used by IPoolHandler to represent a token in a pool
struct IndexedToken {
    uint8 index;
    address token;
}
