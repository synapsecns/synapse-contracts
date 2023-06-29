// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultAdapter} from "../../../contracts/router/adapters/DefaultAdapter.sol";

contract FlakyAdapter is DefaultAdapter {
    function _adapterSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes memory rawParams
    ) internal virtual override returns (uint256 amountOut) {
        // Return inflated amountOut
        amountOut = super._adapterSwap(recipient, tokenIn, amountIn, tokenOut, rawParams) + 1;
    }
}
