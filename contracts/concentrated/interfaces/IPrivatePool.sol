// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";

/// @title Private pool for concentrated liquidity
/// @notice Allows LP to offer fixed price quote in private pool to bridgers for tighter prices
/// @dev Obeys constant sum P * x + y = D curve, where P is fixed price and D is liquidity
/// @dev Functions use same signatures as Swap.sol for easier integration
interface IPrivatePool {
    function factory() external view returns (address);

    function owner() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function P() external view returns (uint256);

    function fee() external view returns (uint256);

    function adminFee() external view returns (uint256);

    /// @notice Updates the quote price LP is willing to offer tokens at
    /// @param _P The new fixed price LP is willing to buy and sell at
    function quote(uint256 _P) external;

    /// @notice Updates the fee applied on swaps
    /// @dev Effectively acts as bid/ask spread for LP
    /// @param _fee The new swap fee
    function setSwapFee(uint256 _fee) external;

    /// @notice Updates the admin fee applied on private pool swaps
    /// @dev Admin fees sent to factory owner
    /// @param _fee The new admin fee
    function setAdminFee(uint256 _fee) external;

    /// @notice Adds liquidity to pool
    /// @param amounts The token amounts to add in token decimals
    /// @param deadline The deadline before which liquidity must be added
    function addLiquidity(uint256[] calldata amounts, uint256 deadline) external returns (uint256 minted_);

    /// @notice Removes liquidity from pool
    /// @param amounts The token amounts to remove in token decimals
    /// @param deadline The deadline before which liquidity must be removed
    function removeLiquidity(uint256[] calldata amounts, uint256 deadline) external returns (uint256 burned_);

    /// @notice Swaps token from for an amount of token to
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    /// @param minDy The minimum amount of token out in token decimals
    /// @param deadline The deadline before which swap must be executed
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256 dy_);

    /// @notice Transfers protocol fees out
    /// @param recipient The recipient address of the aggregated admin fees
    function skim(address recipient) external;

    /// @notice Calculates amount of tokens received on swap
    /// @dev Reverts if either token index is invalid
    /// @param tokenIndexFrom The index of the token in
    /// @param tokenIndexTo The index of the token out
    /// @param dx The amount of token in in token decimals
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 dy_);

    /// @notice Address of the pooled token at given index
    /// @dev Reverts for invalid token index
    /// @param index The index of the token
    function getToken(uint8 index) external view returns (IERC20);

    /// @notice D liquidity for current pool balance state
    function D() external view returns (uint256);
}
