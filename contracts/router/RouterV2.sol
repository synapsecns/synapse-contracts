// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

import {DefaultRouter} from "./DefaultRouter.sol";
import {ModuleIdExists} from "./libs/Errors.sol";
import {BridgeToken, DestRequest, SwapQuery} from "./libs/Structs.sol";
import {IRouterV2} from "./interfaces/IRouterV2.sol";

contract RouterV2 is IRouterV2, DefaultRouter, Ownable {
    /// @inheritdoc IRouterV2
    mapping(bytes32 => address) public idToModule;

    /// @inheritdoc IRouterV2
    mapping(address => bytes32) public moduleToId;

    /// @notice
    event ModuleConnected(bytes32 moduleId, address indexed bridgeModule);

    /// @inheritdoc IRouterV2
    function bridgeViaSynapse(
        address to,
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {}

    /// @inheritdoc IRouterV2
    function swap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external payable returns (uint256 amountOut) {}

    /// @inheritdoc IRouterV2
    function connectBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (idToModule[moduleId] != address(0)) revert ModuleIdExists();
        idToModule[moduleId] = bridgeModule;
        moduleToId[bridgeModule] = moduleId;
        emit ModuleConnected(moduleId, bridgeModule);
    }

    /// @inheritdoc IRouterV2
    function getDestinationBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory destTokens) {}

    /// @inheritdoc IRouterV2
    function getOriginBridgeTokens(address tokenIn) external view returns (BridgeToken[] memory originTokens) {}

    /// @inheritdoc IRouterV2
    function getSupportedTokens() external view returns (address[] memory supportedTokens) {}

    /// @inheritdoc IRouterV2
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries)
    {}

    /// @inheritdoc IRouterV2
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {}
}
