// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "./IRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface IBridgeRouter is IRouter {
    function bridgeMaxSwaps() external view returns (uint8);

    function bridge() external view returns (address);

    // -- SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps) external;

    // -- BRIDGE FUNCTIONS [initial chain] --

    function bridgeToken(
        IERC20 _bridgeToken,
        uint256 _bridgeAmount,
        bytes calldata _bridgeData
    ) external;

    function swapAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external returns (uint256 _amountOut);

    function swapFromGasAndBridge(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        bytes calldata _bridgeData
    ) external payable returns (uint256 _amountOut);

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
    ) external returns (uint256 _amountOut);
}
