// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {QuoteExactInputSingleParams} from "../uniswap/UniswapV3Structs.sol";

// Eden's UniswapV3 static quoter interface
interface IUniswapV3StaticQuoter {
    /// @notice Returns the amount out received for a given exact input but for a swap of a single pool
    /// @param params The params for the quote, encoded as `QuoteExactInputSingleParams`
    /// tokenIn The token being swapped in
    /// tokenOut The token being swapped out
    /// fee The fee of the token pool to consider for the pair
    /// amountIn The desired input amount
    /// sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of `tokenOut` that would be received
    function quoteExactInputSingle(QuoteExactInputSingleParams memory params) external view returns (uint256 amountOut);
}
