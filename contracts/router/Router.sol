// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IRouter} from "./interfaces/IRouter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {BasicRouter} from "./BasicRouter.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts-4.5.0/security/ReentrancyGuard.sol";

// solhint-disable reason-string

contract Router is ReentrancyGuard, BasicRouter, IRouter {
    using SafeERC20 for IERC20;

    constructor(address payable _wgas) BasicRouter(_wgas) {
        this;
    }

    modifier deadlineCheck(uint256 deadline) {
        // solhint-disable-next-line
        require(block.timestamp <= deadline, "Router: past deadline");

        _;
    }

    // -- SWAPPERS [single chain swaps] --

    /**
        @notice Perform a series of swaps along the token path, using the provided Adapters
        @dev 1. Tokens will be pulled from msg.sender, so make sure Router has enough allowance to 
                spend initial token. 
             2. Use Quoter.getTradeDataAmountOut() -> _tradeData to find best route with preset slippage.
             3. len(path) = N, len(adapters) = N - 1
        @param amountIn amount of initial tokens to swap
        @param minAmountOut minimum amount of final tokens for a swap to be successful
        @param path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param adapters adapters that will be used for swap. adapters[i]: swap path[i] -> path[i + 1]
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function swap(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external deadlineCheck(deadline) returns (uint256 amountOut) {
        amountOut = _swap(to, path, adapters, amountIn, minAmountOut);
    }

    /**
        @notice Perform a series of swaps along the token path, starting with
                chain's native currency (GAS), using the provided Adapters.
        @dev 1. Make sure to set amountIn = msg.value, path[0] = WGAS
             2. Use Quoter.getTradeDataAmountOut() -> _tradeData to find best route with preset slippage.
             3. len(path) = N, len(adapters) = N - 1
        @param amountIn amount of initial tokens to swap
        @param minAmountOut minimum amount of final tokens for a swap to be successful
        @param path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param adapters adapters that will be used for swap. adapters[i]: swap path[i] -> path[i + 1]
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function swapFromGAS(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external payable deadlineCheck(deadline) returns (uint256 amountOut) {
        require(msg.value == amountIn, "Router: incorrect amount of GAS");
        require(path[0] == WGAS, "Router: Path needs to begin with WGAS");
        _wrap(amountIn);
        // WGAS tokens need to be sent from this contract
        amountOut = _selfSwap(to, path, adapters, amountIn, minAmountOut);
    }

    /**
        @notice Perform a series of swaps along the token path, ending with
                chain's native currency (GAS), using the provided Adapters.
        @dev 1. Tokens will be pulled from msg.sender, so make sure Router has enough allowance to 
                spend initial token.
             2. Make sure to set path[N-1] = WGAS
             3. Address to needs to be able to accept native GAS
             4. Use Quoter.getTradeDataAmountOut() -> _tradeData to find best route with preset slippage.
             5. len(path) = N, len(adapters) = N - 1
        @param amountIn amount of initial tokens to swap
        @param minAmountOut minimum amount of final tokens for a swap to be successful
        @param path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param adapters adapters that will be used for swap. adapters[i]: swap path[i] -> path[i + 1]
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function swapToGAS(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external deadlineCheck(deadline) returns (uint256 amountOut) {
        require(path[path.length - 1] == WGAS, "Router: Path needs to end with WGAS");
        // This contract needs to receive WGAS in order to unwrap it
        amountOut = _swap(address(this), path, adapters, amountIn, minAmountOut);
        // this will unwrap WGAS and return GAS
        // reentrancy not an issue here, as all work is done
        _returnTokensTo(to, IERC20(WGAS), amountOut);
    }

    // -- INTERNAL SWAP FUNCTIONS --

    /// @dev All internal swap functions have a reentrancy guard

    /**
        @notice Pull tokens from msg.sender and perform a series of swaps
        @dev Use _selfSwap if tokens are already in the contract
             Don't do this: _from = address(this);
        @param amountIn amount of initial tokens to swap
        @param minAmountOut minimum amount of final tokens for a swap to be successful
        @param path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param adapters adapters that will be used for swap. adapters[i]: swap path[i] -> path[i + 1]
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function _swap(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal nonReentrant returns (uint256 amountOut) {
        require(path.length > 1, "Router: path too short");
        address tokenIn = path[0];
        address tokenNext = path[1];
        IERC20(tokenIn).safeTransferFrom(msg.sender, _getDepositAddress(adapters[0], tokenIn, tokenNext), amountIn);

        amountOut = _doChainedSwaps(to, path, adapters, amountIn, minAmountOut);
    }

    /**
        @notice Perform a series of swaps, assuming the starting tokens
                are already deposited in this contract
        @param amountIn amount of initial tokens to swap
        @param minAmountOut minimum amount of final tokens for a swap to be successful
        @param path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param adapters adapters that will be used for swap. adapters[i]: swap path[i] -> path[i + 1]
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function _selfSwap(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal nonReentrant returns (uint256 amountOut) {
        require(path.length > 1, "Router: path too short");
        address tokenIn = path[0];
        address tokenNext = path[1];
        IERC20(tokenIn).safeTransfer(_getDepositAddress(adapters[0], tokenIn, tokenNext), amountIn);

        amountOut = _doChainedSwaps(to, path, adapters, amountIn, minAmountOut);
    }

    struct ChainedSwapData {
        address tokenIn;
        address tokenOut;
        address tokenNext;
        IAdapter adapterNext;
        address targetAddress;
    }

    /**
        @notice Perform a series of swaps, assuming the starting tokens
                have already been deposited in the first adapter
        @param amountIn amount of initial tokens to swap
        @param minAmountOut minimum amount of final tokens for a swap to be successful
        @param path token path for the swap, path[0] = initial token, path[N - 1] = final token
        @param adapters adapters that will be used for swap. adapters[i]: swap path[i] -> path[i + 1]
        @param to address to receive final tokens
        @return amountOut Final amount of tokens swapped
     */
    function _doChainedSwaps(
        address to,
        address[] calldata path,
        address[] calldata adapters,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        require(path.length == adapters.length + 1, "Router: wrong amount of adapters/tokens");
        require(to != address(0), "Router: to cannot be zero address");
        for (uint256 i = 0; i < adapters.length; ++i) {
            require(isTrustedAdapter[adapters[i]], "Router: unknown adapter");
        }

        // yo mama's too deep
        ChainedSwapData memory data;
        data.tokenOut = path[0];
        data.tokenNext = path[1];
        data.adapterNext = IAdapter(adapters[0]);

        amountOut = IERC20(path[path.length - 1]).balanceOf(to);

        for (uint256 i = 0; i < adapters.length; ++i) {
            data.tokenIn = data.tokenOut;
            data.tokenOut = data.tokenNext;

            IAdapter adapter = data.adapterNext;
            if (i < adapters.length - 1) {
                data.adapterNext = IAdapter(adapters[i + 1]);
                data.tokenNext = path[i + 2];
                data.targetAddress = data.adapterNext.depositAddress(data.tokenOut, data.tokenNext);
            } else {
                data.targetAddress = to;
            }

            amountIn = adapter.swap(amountIn, data.tokenIn, data.tokenOut, data.targetAddress);
        }
        // figure out how much tokens user received exactly
        amountOut = IERC20(data.tokenOut).balanceOf(to) - amountOut;
        require(amountOut >= minAmountOut, "Router: Insufficient output amount");
        emit Swap(path[0], data.tokenOut, amountIn, amountOut);
    }

    // -- INTERNAL HELPERS

    /**
        @notice Get selected adapter's deposit address
        @dev Return value of address(0) means that adapter
             doesn't support this pair of tokens, thus revert
        @param adapter Adapter in question
        @param tokenIn token to sell
        @param tokenOut token to buy
     */
    function _getDepositAddress(
        address adapter,
        address tokenIn,
        address tokenOut
    ) internal view returns (address depositAddress) {
        depositAddress = IAdapter(adapter).depositAddress(tokenIn, tokenOut);
        require(depositAddress != address(0), "Adapter: unknown tokens");
    }
}
