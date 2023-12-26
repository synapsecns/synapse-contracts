// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultRouter} from "../router/DefaultRouter.sol";
import {IFastBridge} from "./interfaces/IFastBridge.sol";
import {IFastBridgeRouter, SwapQuery} from "./interfaces/IFastBridgeRouter.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract FastBridgeRouter is DefaultRouter, Ownable, IFastBridgeRouter {
    address public immutable fastBridge;

    constructor(address fastBridge_, address owner_) {
        fastBridge = fastBridge_;
        transferOwnership(owner_);
    }

    /// @inheritdoc IFastBridgeRouter
    function bridge(
        address recipient,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {}

    /// @inheritdoc IFastBridgeRouter
    function getOriginAmountOut(
        address tokenIn,
        address[] memory bridgeTokens,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {}
}
