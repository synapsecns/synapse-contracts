// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/ISwap.sol";
import "../interfaces/ISwapAdapter.sol";
import "../interfaces/ISwapQuoter.sol";
import "../interfaces/IWETH9.sol";
import "../libraries/UniversalToken.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract SynapseAdapter is Ownable, ISwapAdapter, ISwapQuoter {
    using SafeERC20 for IERC20;
    using UniversalToken for address;

    uint256 internal constant MAX_UINT = type(uint256).max;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Address of the local SwapQuoter contract
    ISwapQuoter public swapQuoter;

    /// @notice Receive function to enable unwrapping ETH into this contract
    receive() external payable {} // solhint-disable-line no-empty-blocks

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
     * @notice Performs a tokenIn -> tokenOut swap, according to the provided params.
     * If tokenIn is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
     * If tokenIn is ERC20, the tokens should be already transferred to this contract (using `msg.value = 0`).
     * If tokenOut is ETH_ADDRESS, native ETH will be sent to the recipient (be aware of potential reentrancy).
     * If tokenOut is ERC20, the tokens will be transferred to the recipient.
     * @dev Contracts implementing {ISwapAdapter} interface are required to enforce the above restrictions.
     * On top of that, they must ensure that exactly `amountOut` worth of `tokenOut` is transferred to the recipient.
     * Swap deadline and slippage is checked outside of this contract.
     * @dev Applied to SynapseAdapter only:
     * Use `params.pool = address(this)` for ETH handling without swaps:
     * 1. For wrapping ETH: tokenIn = ETH_ADDRESS, tokenOut = WETH, params.pool = address(this)
     * 2. For unwrapping WETH: tokenIn = WETH, tokenOut = ETH_ADDRESS, params.pool = address(this)
     * If `params.pool != address(this)`, and ETH_ADDRESS was supplied as tokenIn or tokenOut,
     * a corresponding pool token will be treated as WETH.
     * @param to            Address to receive the swapped token
     * @param tokenIn       Token to sell (use ETH_ADDRESS to start from native ETH)
     * @param amountIn      Amount of tokens to sell
     * @param tokenOut      Token to buy (use ETH_ADDRESS to end with native ETH)
     * @param rawParams     Additional swap parameters
     * @return amountOut    Amount of bought tokens
     */
    function adapterSwap(
        address to,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes calldata rawParams
    ) external payable override returns (uint256 amountOut) {
        // We define a few phases for the whole swap process.
        // (?) means the phase is optional.
        // (!) means the phase is mandatory.

        // ============================== PHASE 0(!): CHECK ALL THE PARAMS =========================
        require(tokenIn != tokenOut, "Swap tokens should differ");
        // Decode params for swapping via a Synapse pool
        SynapseParams memory params = abi.decode(rawParams, (SynapseParams));
        // Swap pool should exist, if action other than HandleEth was requested
        require(params.pool != address(0) || params.action == Action.HandleEth, "!pool");

        // ============================== PHASE 1(?): WRAP RECEIVED ETH ============================
        // tokenIn was already transferred to this contract, check if we start from native ETH
        if (tokenIn == UniversalToken.ETH_ADDRESS) {
            // Determine WETH address: this is either tokenOut (if no swap is needed),
            // or a pool token with index `tokenIndexFrom` (if swap is needed).
            tokenIn = _deriveWethAddress({token: tokenOut, params: params, isWethIn: true});
            // Wrap ETH into WETH and leave it in this contract
            _wrapETH(tokenIn, amountIn);
        } else {
            // For ERC20 tokens msg.value should be zero
            require(msg.value == 0, "Incorrect tokenIn for ETH swap");
        }
        // Either way, this contract has `amountIn` worth of `tokenIn`; tokenIn != ETH_ADDRESS

        // ============================== PHASE 2(?): PREPARE TO UNWRAP SWAPPED WETH ===============
        address tokenSwapTo = tokenOut;
        // Check if swap to native ETH was requested
        if (tokenOut == UniversalToken.ETH_ADDRESS) {
            // Determine WETH address: this is either tokenIn (if no swap is needed),
            // or a pool token with index `tokenIndexTo` (if swap is needed).
            tokenSwapTo = _deriveWethAddress({token: tokenIn, params: params, isWethIn: false});
        }
        // Either way, we need to perform tokenIn -> tokenSwapTo swap.
        // Then we need to send tokenOut to the recipient.
        // The last step includes WETH unwrapping, if tokenOut is ETH_ADDRESS

        // ============================== PHASE 3(?): PERFORM A REQUESTED SWAP =====================
        // Determine if we need to perform a swap
        if (params.action == Action.HandleEth) {
            // If no swap is required, amountOut doesn't change
            amountOut = amountIn;
        } else {
            // Approve token for spending if needed
            tokenIn.universalApproveInfinity(params.pool);
            if (params.action == Action.Swap) {
                // Perform a swap through the pool
                amountOut = _swap(ISwap(params.pool), params, amountIn, tokenSwapTo);
            } else if (params.action == Action.AddLiquidity) {
                // Add liquidity to the pool
                amountOut = _addLiquidity(ISwap(params.pool), params, amountIn, tokenSwapTo);
            } else {
                // Remove liquidity to the pool
                amountOut = _removeLiquidity(ISwap(params.pool), params, amountIn, tokenSwapTo);
            }
        }
        // Either way, this contract has `amountOut` worth of `tokenSwapTo`

        // ============================== PHASE 4(?): UNWRAP SWAPPED WETH ==========================
        // Check if swap to native ETH was requested
        if (tokenOut == UniversalToken.ETH_ADDRESS) {
            // We stored WETH address in `tokenSwapTo` previously, let's unwrap it
            _unwrapETH(tokenSwapTo, amountOut);
        }
        // Either way, we need to transfer `amountOut` worth of `tokenOut`

        // ============================== PHASE 5(!): TRANSFER SWAPPED TOKENS ======================
        tokenOut.universalTransfer(to, amountOut);
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
    function poolTokens(address pool) public view override returns (PoolToken[] memory tokens) {
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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         INTERNAL: WETH LOGIC                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Derives WETH address from swap parameters.
    function _deriveWethAddress(
        address token,
        SynapseParams memory params,
        bool isWethIn
    ) internal view returns (address weth) {
        if (params.action == Action.HandleEth) {
            // If we only need to wrap/unwrap ETH, WETH address should be specified as the other token
            weth = token;
        } else {
            // Otherwise, we need to get WETH address from the liquidity pool
            weth = address(ISwap(params.pool).getToken(isWethIn ? params.tokenIndexFrom : params.tokenIndexTo));
        }
    }

    /// @dev Wraps ETH into WETH.
    function _wrapETH(address weth, uint256 amount) internal {
        require(msg.value == amount, "!msg.value");
        // Deposit in order to have WETH in this contract
        IWETH9(payable(weth)).deposit{value: amount}();
    }

    /// @dev Unwraps WETH into ETH.
    function _unwrapETH(address weth, uint256 amount) internal {
        // Withdraw ETH to this contract
        IWETH9(payable(weth)).withdraw(amount);
    }
}
