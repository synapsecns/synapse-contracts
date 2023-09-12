// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {IUniswapV3Pair} from "../../../interfaces/uniswap/IUniswapV3Pair.sol";
import {ExactInputSingleParams, IUniswapV3Router} from "../../../interfaces/uniswap/IUniswapV3Router.sol";
// prettier-ignore
import {
    QuoteExactInputSingleParams, IUniswapV3StaticQuoter
} from "../../../interfaces/uniswap/IUniswapV3StaticQuoter.sol";
import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";
import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

contract UniswapV3Module is OnlyDelegateCall, IPoolModule {
    using UniversalTokenLib for address;

    /// These need to be immutable in order to be accessed via delegatecall
    IUniswapV3Router public immutable uniswapV3Router;
    IUniswapV3StaticQuoter public immutable uniswapV3StaticQuoter;

    constructor(address uniswapV3Router_, address uniswapV3StaticQuoter_) {
        uniswapV3Router = IUniswapV3Router(uniswapV3Router_);
        uniswapV3StaticQuoter = IUniswapV3StaticQuoter(uniswapV3StaticQuoter_);
    }

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // This function should be only called via delegatecall
        assertDelegateCall();
        address tokenIn = tokenFrom.token;
        tokenIn.universalApproveInfinity(address(uniswapV3Router), amountIn);
        // Prepare Uniswap Router params for the swap, see for reference:
        // https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps#swap-input-parameters
        // We set `amountOutMinimum` to 0, as the slippage checks are done outside of Pool Module
        // We set `sqrtPriceLimitX96` to 0, as we don't want to limit the price (same reason as above)
        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenTo.token,
            fee: IUniswapV3Pair(pool).fee(),
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        // Swap the tokens, we can trust Uniswap Router to return the correct amountOut
        amountOut = uniswapV3Router.exactInputSingle(params);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool // probePaused
    ) external view returns (uint256 amountOut) {
        // We are ignoring the probePaused flag because Uniswap pools cannot be paused
        // See `poolSwap()` for more details on the parameters
        QuoteExactInputSingleParams memory params = QuoteExactInputSingleParams({
            tokenIn: tokenFrom.token,
            tokenOut: tokenTo.token,
            amountIn: amountIn,
            fee: IUniswapV3Pair(pool).fee(),
            sqrtPriceLimitX96: 0
        });
        amountOut = uniswapV3StaticQuoter.quoteExactInputSingle(params);
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        // Uniswap pools always have exactly 2 tokens
        tokens = new address[](2);
        tokens[0] = IUniswapV3Pair(pool).token0();
        tokens[1] = IUniswapV3Pair(pool).token1();
    }
}
