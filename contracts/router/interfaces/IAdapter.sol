// SPDX-License-Identifier: MIT
pragma solidity >=0.6;

interface IAdapter {
    event UpdatedGasEstimate(address indexed adapter, uint256 newEstimate);

    event Recovered(address indexed asset, uint256 amount);

    function name() external view returns (string memory);

    function swapGasEstimate() external view returns (uint256);

    function depositAddress(address tokenIn, address tokenOut)
        external
        view
        returns (address);

    function swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) external returns (uint256);

    function query(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256);
}
