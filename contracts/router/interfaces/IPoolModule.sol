// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexedToken} from "../libs/Structs.sol";

interface IPoolModule {
    /// @notice Performs a swap via the given pool, assuming `tokenFrom` is already in the contract.
    /// After the call, the contract should have custody over the received `tokenTo` tokens.
    /// @dev This will be used via delegatecall from LinkedPool, which will have the custody over the initial tokens,
    /// and will only use the correct pool address for interacting with the Pool Module.
    /// Note: Pool Module is responsible for issuing the token approvals, if `pool` requires them.
    /// Note: execution needs to be reverted, if swap fails for any reason.
    /// @param pool         Address of the pool
    /// @param tokenFrom    Token to swap from
    /// @param tokenTo      Token to swap to
    /// @param amountIn     Amount of tokenFrom to swap
    /// @return amountOut   Amount of tokenTo received after the swap
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    /// @notice Returns a quote for a swap via the given pool.
    /// @dev This will be used by LinkedPool, which is supposed to pass only the correct pool address.
    /// Note: Pool Module should bubble the revert, if pool quote fails for any reason.
    /// Note: Pool Module should only revert if the pool is paused, if `probePaused` is true.
    /// @param pool         Address of the pool
    /// @param tokenFrom    Token to swap from
    /// @param tokenTo      Token to swap to
    /// @param amountIn     Amount of tokenFrom to swap
    /// @param probePaused  Whether to check if the pool is paused
    /// @return amountOut   Amount of tokenTo received after the swap
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut);

    /// @notice Returns the list of tokens in the pool. Tokens should be returned in the same order
    /// that is used by the pool for indexing.
    /// @dev Execution needs to be reverted, if pool tokens retrieval fails for any reason, e.g.
    /// if the given pool is not compatible with the Pool Module.
    /// @param pool         Address of the pool
    /// @param tokensAmount Amount of tokens to return
    /// @return tokens      Array of tokens in the pool
    function getPoolTokens(address pool, uint256 tokensAmount) external view returns (address[] memory tokens);
}
