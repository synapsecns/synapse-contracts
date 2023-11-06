// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {IAlgebraPool} from "../../../interfaces/algebra/IAlgebraPool.sol";
import {ExactInputSingleParams, IAlgebraRouter} from "../../../interfaces/algebra/IAlgebraRouter.sol";
// prettier-ignore
import {
    QuoteExactInputSingleParams, IAlgebraStaticQuoter
} from "../../../interfaces/algebra/IAlgebraStaticQuoter.sol";
import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";
import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

contract AlgebraModule is OnlyDelegateCall, IPoolModule {
    using UniversalTokenLib for address;

    /// These need to be immutable in order to be accessed via delegatecall
    IAlgebraRouter public immutable algebraRouter;
    IAlgebraStaticQuoter public immutable algebraStaticQuoter;

    constructor(address algebraRouter_, address algebraStaticQuoter_) {
        algebraRouter = IAlgebraRouter(algebraRouter_);
        algebraStaticQuoter = IAlgebraStaticQuoter(algebraStaticQuoter_);
    }

    /// @inheritdoc IPoolModule
    function poolSwap(
        address,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // This function should be only called via delegatecall
        assertDelegateCall();
        address tokenIn = tokenFrom.token;
        tokenIn.universalApproveInfinity(address(algebraRouter), amountIn);
        // Prepare Algebra Router params for the swap, see for reference:
        // https://docs.algebra.finance/en/docs/contracts/guides/swaps/single-swaps
        // We set `amountOutMinimum` to 0, as the slippage checks are done outside of Pool Module
        // We set `limitSqrtPrice` to 0, as we don't want to limit the price (same reason as above)
        ExactInputSingleParams memory params = ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenTo.token,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            limitSqrtPrice: 0
        });
        // Swap the tokens, we can trust Algebra Router to return the correct amountOut
        amountOut = algebraRouter.exactInputSingle(params);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool // probePaused
    ) external view returns (uint256 amountOut) {
        // We are ignoring the probePaused flag because Algebra pools cannot be paused
        // See `poolSwap()` for more details on the parameters
        QuoteExactInputSingleParams memory params = QuoteExactInputSingleParams({
            tokenIn: tokenFrom.token,
            tokenOut: tokenTo.token,
            amountIn: amountIn,
            limitSqrtPrice: 0
        });
        amountOut = algebraStaticQuoter.quoteExactInputSingle(params);
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        // Algebra pools always have exactly 2 tokens
        tokens = new address[](2);
        tokens[0] = IAlgebraPool(pool).token0();
        tokens[1] = IAlgebraPool(pool).token1();
    }
}
