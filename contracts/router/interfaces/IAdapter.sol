// SPDX-License-Identifier: MIT
pragma solidity >=0.6;

interface IAdapter {
    event AdapterSwap(
        address indexed _tokenIn,
        address indexed _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut
    );

    event UpdatedGasEstimate(address indexed _adapter, uint256 _newEstimate);

    event Recovered(address indexed _asset, uint256 amount);

    function name() external view returns (string memory);
    function swapGasEstimate() external view returns (uint);

	function depositAddress(address _tokenIn, address _tokenOut) external view returns (address);
	function swap(uint256 _amountIn, address _tokenIn, address _tokenOut, address _to) external returns (uint256);
    function query(uint256 _amountIn, address _tokenIn, address _tokenOut) external view returns (uint256);
}