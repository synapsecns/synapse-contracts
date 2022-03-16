// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "./IRouter.sol";

interface IBridgeRouter is IRouter {
	function bridgeMaxSwaps() external view returns (uint8);

	function bridge() external view returns (address);

	// -- SETTERS --

	function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps) external;

	// -- BRIDGE FUNCTIONS [initial chain] --

    function swapAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external;

    function swapFromGasAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external payable;

    // -- BRIDGE FUNCTIONS [destination chain] --

    function refundToAddress(
        address _token,
        uint256 _amount,
        address _to
    ) external;

    function selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256);
}