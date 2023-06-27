// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexedToken, IPoolModule} from "../../interfaces/IPoolModule.sol";
import {IUniswapV3Pair} from "../interfaces/IUniswapV3Pair.sol";
import {IUniswapV3Router} from "../interfaces/IUniswapV3Router.sol";
import {IUniswapV3StaticQuoter} from "../interfaces/IUniswapV3StaticQuoter.sol";
import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

import {ExactInputSingleParams, QuoteExactInputSingleParams} from "./UniswapV3Structs.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract UniswapV3Module is OnlyDelegateCall, IPoolModule {
    using SafeERC20 for IERC20;

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
        IERC20(tokenIn).safeApprove(address(uniswapV3Router), amountIn);

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
        tokens = new address[](2);
        tokens[0] = IUniswapV3Pair(pool).token0();
        tokens[1] = IUniswapV3Pair(pool).token1();
    }
}
