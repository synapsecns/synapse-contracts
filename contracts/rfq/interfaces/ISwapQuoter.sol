// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LimitedToken, SwapQuery} from "../../router/libs/Structs.sol";

interface ISwapQuoter {
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query);
}
