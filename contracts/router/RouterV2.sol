// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

import {DefaultRouter} from "./DefaultRouter.sol";
import {BridgeFailed, ModuleExists, ModuleNotExists} from "./libs/Errors.sol";
import {BridgeToken, DestRequest, SwapQuery} from "./libs/Structs.sol";
import {IBridgeModule} from "./interfaces/IBridgeModule.sol";
import {IRouterV2} from "./interfaces/IRouterV2.sol";

contract RouterV2 is IRouterV2, DefaultRouter, Ownable {
    /// @inheritdoc IRouterV2
    mapping(bytes32 => address) public idToModule;

    /// @inheritdoc IRouterV2
    mapping(address => bytes32) public moduleToId;

    event ModuleConnected(bytes32 moduleId, address indexed bridgeModule);
    event SynapseBridged(
        address indexed to,
        uint256 indexed chainId,
        bytes32 moduleId,
        address indexed token,
        uint256 amount
    );

    /// @inheritdoc IRouterV2
    function bridgeViaSynapse(
        address to,
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {
        address bridgeModule = idToModule[moduleId];
        if (bridgeModule == address(0)) revert ModuleNotExists();

        // pull (and possibly swap) token into router
        if (_hasAdapter(originQuery)) {
            (token, amount) = _doSwap(address(this), token, amount, originQuery);
        } else {
            _pullToken(address(this), token, amount);
        }

        // delegate bridge call to module
        // @dev delegatecall should approve to spend
        bytes memory payload = abi.encodeWithSelector(
            IBridgeModule.delegateBridge.selector,
            to,
            chainId,
            token,
            amount,
            destQuery
        );
        (bool success, bytes memory result) = bridgeModule.delegatecall(payload);
        if (!success) revert BridgeFailed();

        emit SynapseBridged(to, chainId, moduleId, token, amount);
    }

    /// @inheritdoc IRouterV2
    function swap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external payable returns (uint256 amountOut) {}

    /// @inheritdoc IRouterV2
    function connectBridgeModule(bytes32 moduleId, address bridgeModule) external onlyOwner {
        if (idToModule[moduleId] != address(0)) revert ModuleExists();
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

    /// @notice Checks whether the router adapter was specified in the query.
    /// Query without a router adapter specifies that no action needs to be taken.
    function _hasAdapter(SwapQuery memory query) internal pure returns (bool) {
        return query.routerAdapter != address(0);
    }
}
