// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "./IRouter.sol";
import {IBridge} from "../../vault/interfaces/IBridge.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface IBridgeRouter is IRouter {
    function bridgeMaxSwaps() external view returns (uint8);

    function bridge() external view returns (address);

    // -- SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps) external;

    // -- BRIDGE FUNCTIONS [initial chain]: to EVM chains --

    function bridgeTokenToEVM(
        IERC20 _tokenIn,
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _destinationSwapParams
    ) external returns (uint256 _amountBridged);

    function bridgeGasToEVM(
        IBridge.SwapParams calldata _initialSwapParams,
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _destinationSwapParams
    ) external payable returns (uint256 _amountBridged);

    // -- BRIDGE FUNCTIONS [initial chain]: to non-EVM chains --

    function bridgeTokenToNonEVM(
        IERC20 _tokenIn,
        uint256 _amountIn,
        IBridge.SwapParams calldata _initialSwapParams,
        bytes32 _to,
        uint256 _chainId
    ) external returns (uint256 _amountBridged);

    function bridgeGasToNonEVM(
        IBridge.SwapParams calldata _initialSwapParams,
        bytes32 _to,
        uint256 _chainId
    ) external payable returns (uint256 _amountBridged);

    // -- BRIDGE FUNCTIONS [destination chain] --

    function refundToAddress(
        address _token,
        uint256 _amount,
        address _to
    ) external;

    function postBridgeSwap(
        uint256 _amountIn,
        IBridge.SwapParams calldata _swapParams,
        address _to
    ) external returns (uint256 _amountOut);
}
