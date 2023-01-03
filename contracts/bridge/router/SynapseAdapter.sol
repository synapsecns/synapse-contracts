// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/ISwap.sol";
import "../interfaces/ISwapAdapter.sol";
import "../interfaces/ISwapQuoter.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract SynapseAdapter is Ownable, ISwapAdapter, ISwapQuoter {
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Address of the local SwapQuoter contract
    ISwapQuoter public swapQuoter;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              OWNER ONLY                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Sets the Swap Quoter address to get the swap quotes from.
    function setSwapQuoter(ISwapQuoter _swapQuoter) external onlyOwner {
        swapQuoter = _swapQuoter;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          EXTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Performs a tokenIn -> tokenOut swap, according to the provided params,
     * assuming tokenIn was already transferred to this contract.
     * @dev Swap deadline and slippage is checked outside of this contract.
     * @param to            Address to receive the swapped token
     * @param tokenIn       Token to sell
     * @param amountIn      Amount of tokens to sell
     * @param tokenOut      Token to buy
     * @param rawParams     Additional swap parameters
     * @return amountOut    Amount of bought tokens
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
    ▏*║                            VIEWS: QUOTES                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Finds the best pool for tokenIn -> tokenOut swap from the list of supported pools.
     * Returns the `SwapQuery` struct, that can be used on SynapseRouter.
     * minAmountOut and deadline fields will need to be adjusted based on the swap settings.
     */
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (SwapQuery memory) {
        return swapQuoter.getAmountOut(tokenIn, tokenOut, amountIn);
    }

    /**
     * @notice Returns the exact quote for adding liquidity to a given pool
     * in a form of a single token.
     * @param pool      The pool to add tokens to
     * @param amounts   An array of token amounts to deposit.
     *                  The amount should be in each pooled token's native precision.
     *                  If a token charges a fee on transfers, use the amount that gets transferred after the fee.
     * @return LP token amount the user will receive
     */
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view override returns (uint256) {
        return swapQuoter.calculateAddLiquidity(pool, amounts);
    }

    /**
     * @notice Returns the exact quote for swapping between two given tokens.
     * @param pool              The pool to use for the swap
     * @param tokenIndexFrom    The token the user wants to sell
     * @param tokenIndexTo      The token the user wants to buy
     * @param dx                The amount of tokens the user wants to sell. If the token charges a fee on transfers,
     *                          use the amount that gets transferred after the fee.
     * @return amountOut        amount of tokens the user will receive
     */
    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view override returns (uint256 amountOut) {
        amountOut = swapQuoter.calculateSwap(pool, tokenIndexFrom, tokenIndexTo, dx);
    }

    /**
     * @notice Returns the exact quote for withdrawing pools tokens in a balanced way.
     * @param pool          The pool to withdraw tokens from
     * @param amount        The amount of LP tokens that would be burned on withdrawal
     * @return amountsOut   Array of token balances that the user will receive
     */
    function calculateRemoveLiquidity(address pool, uint256 amount)
        external
        view
        override
        returns (uint256[] memory amountsOut)
    {
        amountsOut = swapQuoter.calculateRemoveLiquidity(pool, amount);
    }

    /**
     * @notice Returns the exact quote for withdrawing a single pool token.
     * @param pool          The pool to withdraw a token from
     * @param tokenAmount   The amount of LP token to burn
     * @param tokenIndex    Index of which token will be withdrawn
     * @return amountOut    Calculated amount of underlying token available to withdraw
     */
    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view override returns (uint256 amountOut) {
        amountOut = swapQuoter.calculateWithdrawOneToken(pool, tokenAmount, tokenIndex);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             VIEWS: POOLS                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns a list of all supported pools.
     */
    function allPools() public view override returns (Pool[] memory pools) {
        pools = swapQuoter.allPools();
    }

    /**
     * @notice Returns the amount of tokens the given pool supports and the pool's LP token.
     */
    function poolInfo(address pool) public view override returns (uint256, address) {
        return swapQuoter.poolInfo(pool);
    }

    /**
     * @notice Returns a list of pool tokens for the given pool.
     */
    function poolTokens(address pool) public view override returns (address[] memory tokens) {
        tokens = swapQuoter.poolTokens(pool);
    }

    /**
     * @notice Returns the amount of supported pools.
     */
    function poolsAmount() public view override returns (uint256 amount) {
        amount = swapQuoter.poolsAmount();
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
        (uint256 tokens, address lpToken) = swapQuoter.poolInfo(address(pool));
        // tokenOut should match the LP token
        require(tokenOut == lpToken, "!tokenOut");
        uint256[] memory amounts = new uint256[](tokens);
        amounts[params.tokenIndexFrom] = amountIn;
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
