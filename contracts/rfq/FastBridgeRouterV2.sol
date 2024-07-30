// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultRouter, DeadlineExceeded, InsufficientOutputAmount} from "../router/DefaultRouter.sol";
import {UniversalTokenLib} from "../router/libs/UniversalToken.sol";
import {ActionLib, LimitedToken} from "../router/libs/Structs.sol";
import {IFastBridge} from "./interfaces/IFastBridge.sol";
import {IFastBridgeRouter, SwapQuery} from "./interfaces/IFastBridgeRouter.sol";
import {ISwapQuoter} from "./interfaces/ISwapQuoter.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract FastBridgeRouterV2 is DefaultRouter, Ownable, IFastBridgeRouter {
    using UniversalTokenLib for address;

    error FastBridgeRouterV2__OriginSenderNotSpecified();

    /// @notice Emitted when the swap quoter is set.
    /// @param newSwapQuoter The new swap quoter.
    event SwapQuoterSet(address newSwapQuoter);

    /// @notice Emitted when the new FastBridge contract is set.
    /// @param newFastBridge The new FastBridge contract.
    event FastBridgeSet(address newFastBridge);

    /// @inheritdoc IFastBridgeRouter
    bytes1 public constant GAS_REBATE_FLAG = 0x2A;

    /// @inheritdoc IFastBridgeRouter
    address public fastBridge;
    /// @inheritdoc IFastBridgeRouter
    address public swapQuoter;

    constructor(address owner_) {
        transferOwnership(owner_);
    }

    /// @inheritdoc IFastBridgeRouter
    function setFastBridge(address fastBridge_) external onlyOwner {
        fastBridge = fastBridge_;
        emit FastBridgeSet(fastBridge_);
    }

    /// @inheritdoc IFastBridgeRouter
    function setSwapQuoter(address swapQuoter_) external onlyOwner {
        swapQuoter = swapQuoter_;
        emit SwapQuoterSet(swapQuoter_);
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
        address originSender = _getOriginSender(destQuery.rawParams);
        if (originSender == address(0)) {
            revert FastBridgeRouterV2__OriginSenderNotSpecified();
        }
        if (originQuery.hasAdapter()) {
            // Perform a swap using the swap adapter, set this contract as recipient
            (token, amount) = _doSwap(address(this), token, amount, originQuery);
        } else {
            // Otherwise, pull the token from the user to this contract
            // We still need to perform the deadline and amountOut checks
            // solhint-disable-next-line not-rely-on-time
            if (block.timestamp > originQuery.deadline) {
                revert DeadlineExceeded();
            }
            if (amount < originQuery.minAmountOut) {
                revert InsufficientOutputAmount();
            }
            amount = _pullToken(address(this), token, amount);
        }
        IFastBridge.BridgeParams memory params = IFastBridge.BridgeParams({
            dstChainId: uint32(chainId),
            sender: originSender,
            to: recipient,
            originToken: token,
            destToken: destQuery.tokenOut,
            originAmount: amount,
            destAmount: destQuery.minAmountOut,
            sendChainGas: _chainGasRequested(destQuery.rawParams),
            deadline: destQuery.deadline
        });
        token.universalApproveInfinity(fastBridge, amount);
        uint256 msgValue = token == UniversalTokenLib.ETH_ADDRESS ? amount : 0;
        IFastBridge(fastBridge).bridge{value: msgValue}(params);
    }

    /// @inheritdoc IFastBridgeRouter
    function getOriginAmountOut(
        address tokenIn,
        address[] memory rfqTokens,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {
        uint256 len = rfqTokens.length;
        originQueries = new SwapQuery[](len);
        for (uint256 i = 0; i < len; ++i) {
            originQueries[i] = ISwapQuoter(swapQuoter).getAmountOut(
                LimitedToken({actionMask: ActionLib.allActions(), token: tokenIn}),
                rfqTokens[i],
                amountIn
            );
            // Adjust the Adapter address if it exists
            if (originQueries[i].hasAdapter()) {
                originQueries[i].routerAdapter = address(this);
            }
        }
    }

    /// @dev Retrieves the origin sender from the raw params.
    /// Note: falls back to msg.sender if origin sender is not specified in the raw params, but
    /// msg.sender is an EOA.
    function _getOriginSender(bytes memory rawParams) internal view returns (address originSender) {
        // Origin sender (if present) is encoded as 20 bytes following the rebate flag
        if (rawParams.length >= 21) {
            // The easiest way to read from memory is to use assembly
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Skip the rawParams.length (32 bytes) and the rebate flag (1 byte)
                originSender := mload(add(rawParams, 33))
                // The address is in the highest 160 bits. Shift right by 96 to get it in the lowest 160 bits
                originSender := shr(96, originSender)
            }
        }
        if (originSender == address(0) && msg.sender.code.length == 0) {
            // Fall back to msg.sender if it is an EOA. This maintains backward compatibility
            // for cases where we can safely assume that the origin sender is the same as msg.sender.
            originSender = msg.sender;
        }
    }

    /// @dev Checks if the explicit instruction to send gas to the destination chain was provided.
    function _chainGasRequested(bytes memory rawParams) internal pure returns (bool) {
        return rawParams.length > 0 && rawParams[0] == GAS_REBATE_FLAG;
    }
}
