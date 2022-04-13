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

    function setBridgeMaxSwaps(uint8 bridgeMaxSwaps) external;

    // -- BRIDGE FUNCTIONS [initial chain]: to EVM chains --

    function bridgeTokenToEVM(
        address to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams,
        uint256 amountIn,
        IBridge.SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    ) external returns (uint256 amountBridged);

    function bridgeGasToEVM(
        address to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams,
        IBridge.SwapParams calldata destinationSwapParams,
        bool gasdropRequested
    ) external payable returns (uint256 amountBridged);

    // -- BRIDGE FUNCTIONS [initial chain]: to non-EVM chains --

    function bridgeTokenToNonEVM(
        bytes32 to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams,
        uint256 amountIn
    ) external returns (uint256 amountBridged);

    function bridgeGasToNonEVM(
        bytes32 to,
        uint256 chainId,
        IBridge.SwapParams calldata initialSwapParams
    ) external payable returns (uint256 amountBridged);

    // -- BRIDGE FUNCTIONS [destination chain] --

    function refundToAddress(
        address to,
        IERC20 token,
        uint256 amount
    ) external;

    function postBridgeSwap(
        address to,
        IBridge.SwapParams calldata swapParams,
        uint256 amountIn
    ) external returns (uint256 amountOut);
}
