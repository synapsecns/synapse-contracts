// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPool, IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {IRouterAdapter} from "../interfaces/IRouterAdapter.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {MsgValueIncorrect, PoolNotFound, TokenAddressMismatch, TokensIdentical} from "../libs/Errors.sol";
import {Action, DefaultParams} from "../libs/Structs.sol";
import {UniversalTokenLib} from "../libs/UniversalToken.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract DefaultAdapter is IRouterAdapter {
    using SafeERC20 for IERC20;
    using UniversalTokenLib for address;

    /// @notice Enable this contract to receive Ether when withdrawing from WETH.
    /// @dev Consider implementing rescue functions to withdraw Ether from this contract.
    receive() external payable {}

    /// @inheritdoc IRouterAdapter
    function adapterSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes memory rawParams
    ) external payable returns (uint256 amountOut) {
        return _adapterSwap(recipient, tokenIn, amountIn, tokenOut, rawParams);
    }

    /// @dev Internal logic for doing a tokenIn -> tokenOut swap.
    /// Note: `tokenIn` is assumed to have already been transferred to this contract.
    function _adapterSwap(
        address recipient,
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bytes memory rawParams
    ) internal virtual returns (uint256 amountOut) {
        // We define a few phases for the whole Adapter's swap process.
        // (?) means the phase is optional.
        // (!) means the phase is mandatory.

        // PHASE 0(!): CHECK ALL THE PARAMS
        DefaultParams memory params = _checkParams(tokenIn, tokenOut, rawParams);

        // PHASE 1(?): WRAP RECEIVED ETH INTO WETH
        tokenIn = _wrapReceivedETH(tokenIn, amountIn, tokenOut, params);
        // After PHASE 1 this contract has `amountIn` worth of `tokenIn`, tokenIn != ETH_ADDRESS

        // PHASE 2(?): PREPARE TO UNWRAP SWAPPED WETH
        address tokenSwapTo = _deriveTokenSwapTo(tokenIn, tokenOut, params);
        // We need to perform tokenIn -> tokenSwapTo action in PHASE 3.
        // if tokenOut == ETH_ADDRESS, we need to unwrap WETH in PHASE 4.
        // Recipient will receive `tokenOut` in PHASE 5.

        // PHASE 3(?): PERFORM A REQUESTED SWAP
        amountOut = _performPoolAction(tokenIn, amountIn, tokenSwapTo, params);
        // After PHASE 3 this contract has `amountOut` worth of `tokenSwapTo`, tokenSwapTo != ETH_ADDRESS

        // PHASE 4(?): UNWRAP SWAPPED WETH
        // Check if the final token is native ETH
        if (tokenOut == UniversalTokenLib.ETH_ADDRESS) {
            // PHASE 2: WETH address was stored as `tokenSwapTo`
            _unwrapETH(tokenSwapTo, amountOut);
        }

        // PHASE 5(!): TRANSFER SWAPPED TOKENS TO RECIPIENT
        // Note: this will transfer native ETH, if tokenOut == ETH_ADDRESS
        // Note: this is a no-op if recipient == address(this)
        tokenOut.universalTransfer(recipient, amountOut);
    }

    /// @dev Checks the params and decodes them into a struct.
    function _checkParams(
        address tokenIn,
        address tokenOut,
        bytes memory rawParams
    ) internal pure returns (DefaultParams memory params) {
        if (tokenIn == tokenOut) revert TokensIdentical();
        // Decode params for swapping via a Default pool
        params = abi.decode(rawParams, (DefaultParams));
        // Swap pool should exist, if action other than HandleEth was requested
        if (params.pool == address(0) && params.action != Action.HandleEth) revert PoolNotFound();
    }

    /// @dev Wraps native ETH into WETH, if requested.
    /// Returns the address of the token this contract ends up with.
    function _wrapReceivedETH(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        DefaultParams memory params
    ) internal returns (address wrappedTokenIn) {
        // tokenIn was already transferred to this contract, check if we start from native ETH
        if (tokenIn == UniversalTokenLib.ETH_ADDRESS) {
            // Determine WETH address: this is either tokenOut (if no swap is needed),
            // or a pool token with index `tokenIndexFrom` (if swap is needed).
            wrappedTokenIn = _deriveWethAddress({token: tokenOut, params: params, isTokenFromWeth: true});
            // Wrap ETH into WETH and leave it in this contract
            _wrapETH(wrappedTokenIn, amountIn);
        } else {
            wrappedTokenIn = tokenIn;
            // For ERC20 tokens msg.value should be zero
            if (msg.value != 0) revert MsgValueIncorrect();
        }
    }

    /// @dev Derives the address of token to be received after an action defined in `params`.
    function _deriveTokenSwapTo(
        address tokenIn,
        address tokenOut,
        DefaultParams memory params
    ) internal view returns (address tokenSwapTo) {
        // Check if swap to native ETH was requested
        if (tokenOut == UniversalTokenLib.ETH_ADDRESS) {
            // Determine WETH address: this is either tokenIn (if no swap is needed),
            // or a pool token with index `tokenIndexTo` (if swap is needed).
            tokenSwapTo = _deriveWethAddress({token: tokenIn, params: params, isTokenFromWeth: false});
        } else {
            tokenSwapTo = tokenOut;
        }
    }

    /// @dev Performs an action defined in `params` and returns the amount of `tokenSwapTo` received.
    function _performPoolAction(
        address tokenIn,
        uint256 amountIn,
        address tokenSwapTo,
        DefaultParams memory params
    ) internal returns (uint256 amountOut) {
        // Determine if we need to perform a swap
        if (params.action == Action.HandleEth) {
            // If no swap is required, amountOut doesn't change
            amountOut = amountIn;
        } else {
            // Record balance before the swap
            amountOut = IERC20(tokenSwapTo).balanceOf(address(this));
            // Approve the pool for spending exactly `amountIn` of `tokenIn`
            IERC20(tokenIn).safeIncreaseAllowance(params.pool, amountIn);
            if (params.action == Action.Swap) {
                _swap(params.pool, params, amountIn, tokenSwapTo);
            } else if (params.action == Action.AddLiquidity) {
                _addLiquidity(params.pool, params, amountIn, tokenSwapTo);
            } else {
                // The only remaining action is RemoveLiquidity
                _removeLiquidity(params.pool, params, amountIn, tokenSwapTo);
            }
            // Use the difference between the balance after the swap and the recorded balance as `amountOut`
            amountOut = IERC20(tokenSwapTo).balanceOf(address(this)) - amountOut;
        }
    }

    // ═══════════════════════════════════════ INTERNAL LOGIC: SWAP ACTIONS ════════════════════════════════════════════

    /// @dev Performs a swap through the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _swap(
        address pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal {
        // tokenOut should match the "swap to" token
        if (IDefaultPool(pool).getToken(params.tokenIndexTo) != tokenOut) revert TokenAddressMismatch();
        // amountOut and deadline are not checked in RouterAdapter
        IDefaultPool(pool).swap({
            tokenIndexFrom: params.tokenIndexFrom,
            tokenIndexTo: params.tokenIndexTo,
            dx: amountIn,
            minDy: 0,
            deadline: type(uint256).max
        });
    }

    /// @dev Adds liquidity in a form of a single token to the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _addLiquidity(
        address pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal {
        uint256 numTokens = _getPoolNumTokens(pool);
        address lpToken = _getPoolLPToken(pool);
        // tokenOut should match the LP token
        if (lpToken != tokenOut) revert TokenAddressMismatch();
        uint256[] memory amounts = new uint256[](numTokens);
        amounts[params.tokenIndexFrom] = amountIn;
        // amountOut and deadline are not checked in RouterAdapter
        IDefaultExtendedPool(pool).addLiquidity({amounts: amounts, minToMint: 0, deadline: type(uint256).max});
    }

    /// @dev Removes liquidity in a form of a single token from the given pool.
    /// Note: The pool should be already approved for spending `tokenIn`.
    function _removeLiquidity(
        address pool,
        DefaultParams memory params,
        uint256 amountIn,
        address tokenOut
    ) internal {
        // tokenOut should match the "swap to" token
        if (IDefaultPool(pool).getToken(params.tokenIndexTo) != tokenOut) revert TokenAddressMismatch();
        // amountOut and deadline are not checked in RouterAdapter
        IDefaultExtendedPool(pool).removeLiquidityOneToken({
            tokenAmount: amountIn,
            tokenIndex: params.tokenIndexTo,
            minAmount: 0,
            deadline: type(uint256).max
        });
    }

    // ═════════════════════════════════════════ INTERNAL LOGIC: POOL LENS ═════════════════════════════════════════════

    /// @dev Returns the LP token address of the given pool.
    function _getPoolLPToken(address pool) internal view returns (address lpToken) {
        (, , , , , , lpToken) = IDefaultExtendedPool(pool).swapStorage();
    }

    /// @dev Returns the number of tokens in the given pool.
    function _getPoolNumTokens(address pool) internal view returns (uint256 numTokens) {
        // Iterate over all tokens in the pool until the end is reached
        for (uint8 index = 0; ; ++index) {
            try IDefaultPool(pool).getToken(index) returns (address) {} catch {
                // End of pool reached
                numTokens = index;
                break;
            }
        }
    }

    /// @dev Returns the tokens in the given pool.
    function _getPoolTokens(address pool) internal view returns (address[] memory tokens) {
        uint256 numTokens = _getPoolNumTokens(pool);
        tokens = new address[](numTokens);
        for (uint8 i = 0; i < numTokens; ++i) {
            // This will not revert because we already know the number of tokens in the pool
            tokens[i] = IDefaultPool(pool).getToken(i);
        }
    }

    /// @dev Returns the quote for a swap through the given pool.
    /// Note: will return 0 on invalid swaps.
    function _getPoolSwapQuote(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        try IDefaultPool(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, amountIn) returns (uint256 dy) {
            amountOut = dy;
        } catch {
            // Return 0 instead of reverting
            amountOut = 0;
        }
    }

    // ════════════════════════════════════════ INTERNAL LOGIC: ETH <> WETH ════════════════════════════════════════════

    /// @dev Wraps ETH into WETH.
    function _wrapETH(address weth, uint256 amount) internal {
        if (amount != msg.value) revert MsgValueIncorrect();
        // Deposit in order to have WETH in this contract
        IWETH9(weth).deposit{value: amount}();
    }

    /// @dev Unwraps WETH into ETH.
    function _unwrapETH(address weth, uint256 amount) internal {
        // Withdraw ETH to this contract
        IWETH9(weth).withdraw(amount);
    }

    /// @dev Derives WETH address from swap parameters.
    function _deriveWethAddress(
        address token,
        DefaultParams memory params,
        bool isTokenFromWeth
    ) internal view returns (address weth) {
        if (params.action == Action.HandleEth) {
            // If we only need to wrap/unwrap ETH, WETH address should be specified as the other token
            weth = token;
        } else {
            // Otherwise, we need to get WETH address from the liquidity pool
            weth = address(
                IDefaultPool(params.pool).getToken(isTokenFromWeth ? params.tokenIndexFrom : params.tokenIndexTo)
            );
        }
    }
}
