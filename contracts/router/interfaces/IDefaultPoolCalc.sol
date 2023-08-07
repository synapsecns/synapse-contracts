// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IDefaultPoolCalc {
    /// @notice Calculates the EXACT amount of LP tokens received for a given amount of tokens deposited
    /// into a DefaultPool.
    /// @param pool         Address of the DefaultPool.
    /// @param amounts      Amounts of tokens to deposit.
    /// @return amountOut   Amount of LP tokens received.
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256 amountOut);
}
