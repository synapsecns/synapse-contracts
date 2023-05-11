// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Private factory for concentrated liquidity
/// @notice Deploys individual private pools owned by LPs
interface IPrivateFactory {
    function bridge() external view returns (address);

    function pool(
        address lp,
        address tokenA,
        address tokenB
    ) external view returns (address);

    function orderTokens(address tokenA, address tokenB) external view returns (address, address);

    function deploy(address tokenA, address tokenB) external returns (address);
}
