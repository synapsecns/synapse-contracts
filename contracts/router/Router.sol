// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "./interfaces/IAdapter.sol";
import {ILiquidityAdapter} from "./interfaces/ILiquidityAdapter.sol";
import {IRouter} from "./interfaces/IRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

import {BasicRouter} from "./BasicRouter.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts-4.4.2/security/ReentrancyGuard.sol";

// solhint-disable reason-string

contract Router is ReentrancyGuard, BasicRouter, IRouter {
    using SafeERC20 for IERC20;

    mapping(address => bool) public isTrustedLiquidityAdapter;

    constructor(address payable _wgas) BasicRouter(_wgas) {
        this;
    }

    modifier deadlineCheck(uint256 deadline) {
        // solhint-disable-next-line
        require(block.timestamp <= deadline, "Router: past deadline");

        _;
    }

    modifier onlyTrustedLiquidityAdapter(ILiquidityAdapter adapter) {
        require(
            isTrustedLiquidityAdapter[address(adapter)],
            "Router: unknown adapter"
        );

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
        require(
            path[path.length - 1] == WGAS,
            "Router: Path needs to end with WGAS"
        );
        // This contract needs to receive WGAS in order to unwrap it
        amountOut = _swap(
            address(this),
            path,
            adapters,
            amountIn,
            minAmountOut
        );
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
        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            _getDepositAddress(adapters[0], tokenIn, tokenNext),
            amountIn
        );

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
        IERC20(tokenIn).safeTransfer(
            _getDepositAddress(adapters[0], tokenIn, tokenNext),
            amountIn
        );

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
        require(
            path.length == adapters.length + 1,
            "Router: wrong amount of adapters/tokens"
        );
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
                data.targetAddress = data.adapterNext.depositAddress(
                    data.tokenOut,
                    data.tokenNext
                );
            } else {
                data.targetAddress = to;
            }

            amountIn = adapter.swap(
                amountIn,
                data.tokenIn,
                data.tokenOut,
                data.targetAddress
            );
        }
        // figure out how much tokens user received exactly
        amountOut = IERC20(data.tokenOut).balanceOf(to) - amountOut;
        require(
            amountOut >= minAmountOut,
            "Router: Insufficient output amount"
        );
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

    // -- LIQUIDITY MANAGEMENT

    /**
     * @notice Calculate amount of LP tokens gained after
     * providing given amount of tokens via selected {Adapter}.
     * @param adapter Adapter for the given pool.
     * @param tokens Tokens to add to the given pool.
     * @param amounts Amount of tokens to add.
     * @return lpTokenAmount Estimated amount of LP tokens to gain.
     * @return refund Estimated amount of token refunds, if given pool only allows balanced deposits.
     */
    function calculateAddLiquidity(
        ILiquidityAdapter adapter,
        IERC20[] calldata tokens,
        uint256[] calldata amounts
    ) external view returns (uint256 lpTokenAmount, uint256[] memory refund) {
        (lpTokenAmount, refund) = adapter.calculateAddLiquidity(
            tokens,
            amounts
        );
    }

    /**
     * @notice Calculate amounts of tokens to add, given maximum amount of tokens to spend.
     * @param adapter Adapter for the given pool.
     * @param tokens Tokens to add to the given pool.
     * @param amountsMax Maximum amount of tokens to add.
     * @return amounts Estimated amounts of actually added tokens, if added immediately.
     */
    function calculateAmounts(
        ILiquidityAdapter adapter,
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    ) external view returns (uint256[] memory amounts) {
        (, amounts) = adapter.getTokensDepositInfo(tokens, amountsMax);
    }

    /**
     * @notice Calculate amount of tokens gained after burning a given
     * amount of LP tokens to withdraw all pool tokens in a balanced way.
     * @param adapter Adapter for the given pool.
     * @param lpToken LP token for the given pool.
     * @param lpTokenAmount Amount of LP tokens to burn.
     * @return tokenAmounts Estimated amounts of pools tokens to receive after withdrawal.
     */
    function calculateRemoveLiquidity(
        ILiquidityAdapter adapter,
        IERC20 lpToken,
        uint256 lpTokenAmount
    ) external view returns (uint256[] memory tokenAmounts) {
        tokenAmounts = adapter.calculateRemoveLiquidity(lpToken, lpTokenAmount);
    }

    /**
     * @notice Calculate amount of tokens gained after burning a given
     * amount of LP tokens to withdraw a single token.
     * @param adapter Adapter for the given pool.
     * @param lpToken LP token for the given pool.
     * @param lpTokenAmount Amount of LP tokens to burn.
     * @param token Token to withdraw.
     * @return tokenAmount Estimated amount of given token to receive after withdrawal.
     */
    function calculateRemoveLiquidityOneToken(
        ILiquidityAdapter adapter,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token
    ) external view returns (uint256 tokenAmount) {
        tokenAmount = adapter.calculateRemoveLiquidityOneToken(
            lpToken,
            lpTokenAmount,
            token
        );
    }

    /**
     * @notice Add liquidity to the given pool and receive LP tokens.
     * As much tokens as possible will be used, but not more than specified amounts.
     * @dev This will require allowing Router to spend pool tokens from user.
     * @param adapter Adapter for the given pool.
     * @param tokens Tokens to add to the given pool.
     * @param amountsMax Maximum amount of tokens to add.
     * @param minLpTokensAmount Minimum amount of LP tokens to receive, or the tx will fail.
     * @param deadline Deadline for the pool deposit to happen, or the tx will fail.
     * @return lpTokenAmount Amount of LP tokens gained.
     */
    function addLiquidity(
        ILiquidityAdapter adapter,
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax,
        uint256 minLpTokensAmount,
        uint256 deadline
    )
        external
        nonReentrant
        onlyTrustedLiquidityAdapter(adapter)
        deadlineCheck(deadline)
        returns (uint256 lpTokenAmount)
    {
        require(
            tokens.length == amountsMax.length,
            "Router: arrays length differs"
        );
        // First, find out how much tokens we can deposit
        (address depositAddress, uint256[] memory amounts) = adapter
            .getTokensDepositInfo(tokens, amountsMax);

        // Then, deposit tokens into Adapter
        for (uint256 index = 0; index < tokens.length; ++index) {
            require(
                amounts[index] <= amountsMax[index],
                "Router: amount over maximum"
            );
            tokens[index].safeTransferFrom(
                msg.sender,
                depositAddress,
                amounts[index]
            );
        }
        // Finally, ask Adapter nicely to add liquidity
        lpTokenAmount = adapter.addLiquidity(
            msg.sender,
            tokens,
            amounts,
            minLpTokensAmount
        );
    }

    /**
     * @notice Add liquidity to the given pool, including native GAS and receive LP tokens.
     * As much tokens and GAS as possible will be used, but not more than specified amounts.
     * @dev This will require allowing Router to spend pool tokens from user. This will fail,
     * if WGAS is not in the `tokens` list, or if amount of WGAS is different from `msg.value`.
     * @param adapter Adapter for the given pool.
     * @param tokens Tokens to add to the given pool.
     * @param amountsMax Maximum amount of tokens to add.
     * @param minLpTokensAmount Minimum amount of LP tokens to receive, or the tx will fail.
     * @param deadline Deadline for the pool deposit to happen, or the tx will fail.
     * @return lpTokenAmount Amount of LP tokens gained.
     */
    function addLiquidityGAS(
        ILiquidityAdapter adapter,
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax,
        uint256 minLpTokensAmount,
        uint256 deadline
    )
        external
        payable
        nonReentrant
        onlyTrustedLiquidityAdapter(adapter)
        deadlineCheck(deadline)
        returns (uint256 lpTokenAmount)
    {
        require(
            tokens.length == amountsMax.length,
            "Router: arrays length differs"
        );
        // First, find out how much tokens we can deposit
        (address depositAddress, uint256[] memory amounts) = adapter
            .getTokensDepositInfo(tokens, amountsMax);

        // Track how much GAS Router has leftover after depositing
        uint256 gasRemaining = UINT_MAX;

        // Then, deposit tokens into Adapter
        for (uint256 index = 0; index < tokens.length; ++index) {
            uint256 amount = amounts[index];
            require(amount <= amountsMax[index], "Router: amount over maximum");

            IERC20 token = tokens[index];
            if (address(token) == WGAS) {
                require(
                    amountsMax[index] == msg.value,
                    "Router: wrong amount of GAS"
                );
                // Wrap GAS into WGAS and send in to Adapter
                _wrap(amount);
                token.safeTransfer(depositAddress, amount);
                // Store amount of remaining GAS
                gasRemaining = msg.value - amount;
            } else {
                token.safeTransferFrom(msg.sender, depositAddress, amount);
            }
        }
        require(gasRemaining != UINT_MAX, "Router: WGAS not in the list");
        // Then, ask Adapter nicely to add liquidity
        lpTokenAmount = adapter.addLiquidity(
            msg.sender,
            tokens,
            amounts,
            minLpTokensAmount
        );

        // Return remaining GAS to user
        if (gasRemaining > 0) {
            // solhint-disable-next-line
            (bool success, ) = msg.sender.call{value: gasRemaining}("");
            require(success, "GAS transfer failed");
        }
    }

    /**
     * @notice Remove liquidity from a given pool by burning its LP tokens to withdraw all pool tokens in a balanced way.
     * If one of the tokens was WGAS, user will receive native GAS alongside other tokens.
     * @dev This will require allowing Router to spend LP token from user.
     * @param adapter Adapter for the given pool.
     * @param lpToken LP token for the given pool.
     * @param lpTokenAmount Amount of LP tokens to burn.
     * @param minTokenAmounts Minimum amounts of pool tokens to receive, or the tx will fail.
     * @param unwrapGas Whether to send native GAS instead of WGAS, if it's in the pool
     * @param deadline Deadline for the pool deposit to happen, or the tx will fail.
     * @return tokenAmounts Amounts of pools tokens withdrawn.
     */
    function removeLiquidity(
        ILiquidityAdapter adapter,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        uint256[] calldata minTokenAmounts,
        bool unwrapGas,
        uint256 deadline
    )
        external
        nonReentrant
        onlyTrustedLiquidityAdapter(adapter)
        deadlineCheck(deadline)
        returns (uint256[] memory tokenAmounts)
    {
        // First, deposit LP token into Adapter
        address depositAddress = adapter.getLpTokenDepositAddress(lpToken);
        lpToken.safeTransferFrom(msg.sender, depositAddress, lpTokenAmount);
        // Then, ask Adapter nicely to remove liquidity

        tokenAmounts = adapter.removeLiquidity(
            msg.sender,
            lpToken,
            lpTokenAmount,
            minTokenAmounts,
            unwrapGas,
            IWETH9(WGAS)
        );
    }

    /**
     * @notice Remove liquidity from a given pool by burning its LP tokens to withdraw a single pool token.
     * If that token is WGAS, user will receive native GAS.
     * @dev This will require allowing Router to spend LP token from user.
     * @param adapter Adapter for the given pool.
     * @param lpToken LP token for the given pool.
     * @param lpTokenAmount Amount of LP tokens to burn.
     * @param token Token to withdraw.
     * @param minTokenAmount Minimum amount of pool token to receive, or the tx will fail.
     * @param unwrapGas Whether to send native GAS instead of WGAS, if it's in the pool
     * @param deadline Deadline for the pool deposit to happen, or the tx will fail.
     * @return tokenAmount Amount of pools token withdrawn.
     */
    function removeLiquidityOneToken(
        ILiquidityAdapter adapter,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token,
        uint256 minTokenAmount,
        bool unwrapGas,
        uint256 deadline
    )
        external
        nonReentrant
        onlyTrustedLiquidityAdapter(adapter)
        deadlineCheck(deadline)
        returns (uint256 tokenAmount)
    {
        // First, deposit LP token into Adapter
        address depositAddress = adapter.getLpTokenDepositAddress(lpToken);
        lpToken.safeTransferFrom(msg.sender, depositAddress, lpTokenAmount);
        // Then, ask Adapter nicely to add liquidity
        tokenAmount = adapter.removeLiquidityOneToken(
            msg.sender,
            lpToken,
            lpTokenAmount,
            token,
            minTokenAmount,
            unwrapGas,
            IWETH9(WGAS)
        );
    }
}
