// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PoolQuoterV1} from "./PoolQuoterV1.sol";
import {ISwapQuoterV1, LimitedToken, SwapQuery, Pool, PoolToken} from "../interfaces/ISwapQuoterV1.sol";

contract SwapQuoterV2 is PoolQuoterV1 {
    // solhint-disable-next-line no-empty-blocks
    constructor(address defaultPoolCalc, address weth) PoolQuoterV1(defaultPoolCalc, weth) {}

    // ═════════════════════════════════════════════ GENERAL QUOTES V1 ═════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function findConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        returns (uint256 amountFound, bool[] memory isConnected)
    {}

    /// @inheritdoc ISwapQuoterV1
    function getAmountOut(
        LimitedToken memory tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (SwapQuery memory query) {}
}
