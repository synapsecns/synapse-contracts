// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultRouter} from "../router/DefaultRouter.sol";
import {UniversalTokenLib} from "../router/libs/UniversalToken.sol";
import {IFastBridge} from "./interfaces/IFastBridge.sol";
import {IFastBridgeRouter, SwapQuery} from "./interfaces/IFastBridgeRouter.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract FastBridgeRouter is DefaultRouter, Ownable, IFastBridgeRouter {
    using UniversalTokenLib for address;

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
    ) external payable {
        if (originQuery.hasAdapter()) {
            // Perform a swap using the swap adapter, set this contract as recipient
            (token, amount) = _doSwap(address(this), token, amount, originQuery);
        } else {
            // Otherwise, pull the token from the user to this contract
            amount = _pullToken(address(this), token, amount);
        }
        IFastBridge.BridgeParams memory params = IFastBridge.BridgeParams({
            dstChainId: uint32(chainId),
            sender: msg.sender,
            to: recipient,
            originToken: token,
            destToken: destQuery.tokenOut,
            originAmount: amount,
            destAmount: destQuery.minAmountOut,
            // TODO: proper implementation
            sendChainGas: destQuery.rawParams.length > 0,
            deadline: destQuery.deadline
        });
        token.universalApproveInfinity(fastBridge, amount);
        uint256 msgValue = token == UniversalTokenLib.ETH_ADDRESS ? amount : 0;
        IFastBridge(fastBridge).bridge{value: msgValue}(params);
    }

    /// @inheritdoc IFastBridgeRouter
    function getOriginAmountOut(
        address tokenIn,
        address[] memory bridgeTokens,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {}
}
