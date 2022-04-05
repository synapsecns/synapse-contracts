// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "./IRouter.sol";
import {IBridge} from "../../vault/interfaces/IBridge.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface IBridgeRouter is IRouter {
    // -- VIEWS --

    function bridgeMaxSwaps() external view returns (uint8);

    function bridge() external view returns (address);

    // -- SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps) external;

    // -- BRIDGE FUNCTIONS [initial chain]: to EVM chains --

    function bridgeTokenToEVM(
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams,
        uint256 _amountIn,
        IBridge.SwapParams calldata _destinationSwapParams
    ) external returns (uint256 _amountBridged);

    function bridgeGasToEVM(
        address _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams,
        IBridge.SwapParams calldata _destinationSwapParams
    ) external payable returns (uint256 _amountBridged);

    // -- BRIDGE FUNCTIONS [initial chain]: to non-EVM chains --

    function bridgeTokenToNonEVM(
        bytes32 _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams,
        uint256 _amountIn
    ) external returns (uint256 _amountBridged);

    function bridgeGasToNonEVM(
        bytes32 _to,
        uint256 _chainId,
        IBridge.SwapParams calldata _initialSwapParams
    ) external payable returns (uint256 _amountBridged);

    // -- BRIDGE FUNCTIONS [destination chain] --

    function refundToAddress(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) external;

    function postBridgeSwap(
        address _to,
        IBridge.SwapParams calldata _swapParams,
        uint256 _amountIn
    ) external returns (uint256 _amountOut);
}
