// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultRouter} from "../router/DefaultRouter.sol";
import {UniversalTokenLib} from "../router/libs/UniversalToken.sol";
import {IFastBridge} from "./interfaces/IFastBridge.sol";
import {IFastBridgeRouter, SwapQuery} from "./interfaces/IFastBridgeRouter.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract FastBridgeRouter is DefaultRouter, Ownable, IFastBridgeRouter {
    using UniversalTokenLib for address;

    /// @notice Emitted when the swap quoter is set.
    /// @param newSwapQuoter The new swap quoter.
    event SwapQuoterSet(address newSwapQuoter);

    address public immutable fastBridge;
    /// @notice Magic value that indicates that the user wants to receive gas rebate on the destination chain.
    /// This is the answer to the ultimate question of life, the universe, and everything.
    bytes1 public constant GAS_REBATE_FLAG = 0x2A;

    address public swapQuoter;

    constructor(address fastBridge_, address owner_) {
        fastBridge = fastBridge_;
        transferOwnership(owner_);
    }

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
        address[] memory bridgeTokens,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {}

    /// @dev Checks if the explicit instruction to send gas to the destination chain was provided.
    function _chainGasRequested(bytes memory rawParams) internal pure returns (bool) {
        return rawParams.length > 0 && rawParams[0] == GAS_REBATE_FLAG;
    }
}
