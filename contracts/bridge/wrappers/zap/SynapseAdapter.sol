// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../interfaces/ISwap.sol";
import "../../interfaces/ISwapAdapter.sol";
import "../../interfaces/ISwapQuoter.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

abstract contract SynapseAdapter is ISwapAdapter {
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Address of the local SwapQuoter contract
    ISwapQuoter public swapQuoter;
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          EXTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a tokenIn -> tokenOut swap, according to the provided params.
     * tokenIn should have been already transferred to this contract.
     * tokenOut will be sent to the requested address.
     */
    function swap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external override returns (uint256 amountOut) {
        require(msg.sender == address(this), "External calls not allowed");
        // Decode params for swapping via a Synapse pool
        SynapseParams memory params = abi.decode(rawParams, (SynapseParams));
        ISwap pool = ISwap(params.pool);
        // Swap pool should exist
        require(address(pool) != address(0), "!pool");
        // Approve token for spending if needed
        _approveToken(IERC20(tokenIn), address(pool));
        if (params.action == Action.Swap) {
            // Perform a swap through the pool
            amountOut = _swap(pool, params, amountIn, tokenOut);
        } else if (params.action == Action.AddLiquidity) {
            // Add liquidity to the pool
            amountOut = _addLiquidity(pool, params, amountIn, tokenOut);
        } else {
            // Remove liquidity to the pool
            amountOut = _removeLiquidity(pool, params, amountIn, tokenOut);
        }
        // Transfer tokens out of the contract, if requested
        if (to != address(this)) {
            IERC20(tokenOut).safeTransfer(to, amountOut);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Sets the token allowance for the given spender to infinity.
     */
    function _approveToken(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        // Set allowance to MAX_UINT if needed
        if (allowance != MAX_UINT) {
            // if allowance is neither zero nor infinity, reset if first
            if (allowance != 0) {
                token.safeApprove(spender, 0);
            }
            token.safeApprove(spender, MAX_UINT);
        }
    }

    /**
     * @notice Performs a swap through the given pool.
     * The pool token is already approved for spending.
     */
    function _swap(
        ISwap pool,
        SynapseParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the "swap to" token
        require(pool.getToken(params.tokenIndexTo) == IERC20(tokenOut), "!tokenOut");
        // amountOut and deadline are not checked in SwapAdapter
        amountOut = pool.swap({
            tokenIndexFrom: params.tokenIndexFrom,
            tokenIndexTo: params.tokenIndexTo,
            dx: amountIn,
            minDy: 0,
            deadline: MAX_UINT
        });
    }

    /**
     * @notice Adds liquidity in a form of a single token to the given pool.
     * The pool token is already approved for spending.
     */
    function _addLiquidity(
        ISwap pool,
        SynapseParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the LP token
        require(swapQuoter.poolLpToken(address(pool)) == tokenOut, "!tokenOut");
        uint256 tokens = swapQuoter.poolTokenAmount(address(pool));
        uint256[] memory amounts = new uint256[](tokens);
        for (uint256 t = 0; t < tokens; ++t) {
            if (t == params.tokenIndexFrom) amounts[t] = amountIn;
        }
        // amountOut and deadline are not checked in SwapAdapter
        amountOut = pool.addLiquidity({amounts: amounts, minToMint: 0, deadline: MAX_UINT});
    }

    /**
     * @notice Removes liquidity in a form of a single token from the given pool.
     * The pool LP token is already approved for spending.
     */
    function _removeLiquidity(
        ISwap pool,
        SynapseParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        // tokenOut should match the "swap to" token
        require(pool.getToken(params.tokenIndexTo) == IERC20(tokenOut), "!tokenOut");
        // amountOut and deadline are not checked in SwapAdapter
        amountOut = pool.removeLiquidityOneToken({
            tokenAmount: amountIn,
            tokenIndex: params.tokenIndexTo,
            minAmount: 0,
            deadline: MAX_UINT
        });
    }
}
