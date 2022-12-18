// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../libraries/BridgeStructs.sol";

interface ISwapAdapter {
    function swap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external returns (uint256);
}
