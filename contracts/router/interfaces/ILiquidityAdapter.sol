// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

interface ILiquidityAdapter {
    // -- VIEWS --
    /**
     * @notice Calculate amount of LP tokens received after providing given amounts of tokens.
     * Some pools (Uniswap) require balanced deposits, so actual added amounts are returned as well.
     * @dev As much tokens as possible will be used for the deposit, but not more than amount specified.
     * @param tokens List of tokens to deposit. Should be the same list as `getTokens(lpToken)`.
     * @param amountsMax Maximum amount of tokens user is willing to deposit.
     * @return lpTokenAmount Amount of LP tokens to gain after deposit to pool.
     * @return amounts Actual amounts of tokens that will be deposited.
     */
    function calculateAddLiquidity(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    ) external view returns (uint256 lpTokenAmount, uint256[] memory amounts);

    /**
     * @notice Calculate amounts of tokens received after burning given amount of LP tokens,
     * in order to withdraw tokens from the pool in a balanced way.
     * @param lpToken LP token for the pool.
     * @param lpTokenAmount Amount of LP tokens to burn.
     * @return tokenAmounts Amounts of tokens to gain after doing a balanced withdrawal.
     */
    function calculateRemoveLiquidity(IERC20 lpToken, uint256 lpTokenAmount)
        external
        view
        returns (uint256[] memory tokenAmounts);

    /**
     * @notice Calculate amount of tokens received after burning given amount of LP tokens,
     * in order to withdraw a single token from the pool.
     * @param lpToken LP token for the pool.
     * @param lpTokenAmount Amount of LP tokens to burn.
     * @param token Token to withdraw.
     * @return tokenAmount Amount of token to gain after after doing an unbalanced withdrawal.
     */
    function calculateRemoveLiquidityOneToken(
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token
    ) external view returns (uint256 tokenAmount);

    /**
     * @notice Get a list of tokens from the pool, and their balances.
     * @dev All functions accepting `tokens[]` will require
     * providing exactly this list in the exact same order.
     * @param lpToken LP token for the pool.
     * @return tokens List of pool tokens.
     * @return balances Pool balance for each token in the list.
     */
    function getTokens(IERC20 lpToken)
        external
        view
        returns (IERC20[] memory tokens, uint256[] memory balances);

    /**
     * @notice Get information required to make a deposit into the pool.
     * @dev Transfer exactly `amounts[]` to `tokensDepositAddress`, and then call {addLiquidity}.
     * @param tokens List of tokens to deposit. Should be the same list as `getTokens(lpToken)`.
     * @param amountsMax Maximum amount of tokens user is willing to deposit.
     * @return tokensDepositAddress Address to transfer `tokens` before deposit.
     * @return amounts Actual amounts of tokens to transfer before deposit.
     */
    function getTokensDepositInfo(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    )
        external
        view
        returns (address tokensDepositAddress, uint256[] memory amounts);

    /**
     * @notice Get information required to make a withdrawal from the pool.
     * @dev Transfer needed amount of `lpToken` to `lpTokenDepositAddress` and then call
     * {removeLiquidity} or {removeLiquidityOneToken}.
     * @param lpToken LP token for the pool.
     * @return lpTokenDepositAddress Address to transfer `lpToken` before withdrawal.
     */
    function getLpTokenDepositAddress(IERC20 lpToken)
        external
        view
        returns (address lpTokenDepositAddress);

    // -- INTERACTIONS --

    /**
     * @notice Make a deposit into the pool, assuming tokens have been transferred
     * to `tokensDepositAddress`.
     * @dev Use {getTokensDepositInfo} to get `tokensDepositAddress` and precise `amounts`.
     * Tokens should be wrapped outside of this function.
     * @param to Address to receive LP tokens after deposit.
     * @param tokens List of tokens to deposit. Should be the same list as `getTokens(lpToken)`.
     * @param amounts Exact amounts of tokens to deposit in the pool.
     * @param minLpTokensAmount Minimum amount of LP tokens to receive, or tx will fail.
     * @return lpTokenAmount Amount of LP tokens gained after the deposit.
     */
    function addLiquidity(
        address to,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256 minLpTokensAmount
    ) external returns (uint256 lpTokenAmount);

    /**
     * @notice Make a withdrawal from the pool to receive all pool tokens in a balanced way,
     * assuming LP tokens have been transferred to `lpTokenDepositAddress`.
     * @dev Use {getLpTokenDepositAddress} to get `lpTokenDepositAddress`.
     * Value of `unwrapGas` is ignored, if `wgas` is not a pool token.
     * @param to Address to tokens after withdrawal.
     * @param lpToken LP token for the pool.
     * @param lpTokenAmount Exact amount of LP tokens to burn.
     * @param minTokenAmounts Minimum amounts of tokens to receive, or tx will fail.
     * @param unwrapGas Whether user wants to receive native GAS instead of WGAS.
     * @param wgas Address of WGAS.
     * @return tokenAmounts Amounts of tokens withdrawn.
     */
    function removeLiquidity(
        address to,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        uint256[] calldata minTokenAmounts,
        bool unwrapGas,
        IWETH9 wgas
    ) external returns (uint256[] memory tokenAmounts);

    /**
     * @notice Make a withdrawal from the pool to receive a single pool token,
     * assuming LP tokens have been transferred to `lpTokenDepositAddress`.
     * @dev Use {getLpTokenDepositAddress} to get `lpTokenDepositAddress`.
     * Value of `unwrapGas` is ignored, if `wgas != token`.
     * @param to Address to tokens after withdrawal.
     * @param lpToken LP token for the pool.
     * @param lpTokenAmount Exact amount of LP tokens to burn.
     * @param token Token to withdraw from the pool.
     * @param minTokenAmount Minimum amount of tokens to receive, or tx will fail.
     * @param unwrapGas Whether user wants to receive native GAS instead of WGAS.
     * @param wgas Address of WGAS.
     * @return tokenAmount Amount of tokens withdrawn.
     */
    function removeLiquidityOneToken(
        address to,
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token,
        uint256 minTokenAmount,
        bool unwrapGas,
        IWETH9 wgas
    ) external returns (uint256 tokenAmount);
}
