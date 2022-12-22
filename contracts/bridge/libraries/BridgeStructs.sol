// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

struct SwapQuery {
    address swapAdapter;
    address tokenOut;
    uint256 minAmountOut;
    uint256 deadline;
    bytes rawParams;
}

enum Action {
    Swap,
    AddLiquidity,
    RemoveLiquidity
}

struct SynapseParams {
    Action action;
    address pool;
    uint8 tokenIndexFrom;
    uint8 tokenIndexTo;
}