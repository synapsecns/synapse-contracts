// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {SynapseCCTPModule} from "../../../../contracts/router/modules/bridge/SynapseCCTPModule.sol";

abstract contract SynapseRouterV2CCTPUtils is Test {
    // synapse cctp events
    event CircleRequestSent(
        uint256 chainId,
        address indexed sender,
        uint64 nonce,
        address token,
        uint256 amount,
        uint32 requestVersion,
        bytes formattedRequest,
        bytes32 requestID
    );

    // synapse CCTP events as structs
    struct CircleRequestSentEvent {
        uint256 chainId;
        address sender;
        uint64 nonce;
        address token;
        uint256 amount;
        uint32 requestVersion;
        bytes formattedRequest;
        bytes32 requestID;
    }
    CircleRequestSentEvent internal requestSentEvent;

    // synapse cctp module
    address public synapseCCTP;
    address public synapseCCTPModule;

    function deploySynapseCCTPModule() public virtual {
        require(synapseCCTP != address(0), "synapseCCTP == address(0)");
        synapseCCTPModule = address(new SynapseCCTPModule(synapseCCTP));
    }

    function expectCircleRequestSentEvent() internal {
        vm.expectEmit(synapseCCTP);
        emit CircleRequestSent(
            requestSentEvent.chainId,
            requestSentEvent.sender,
            requestSentEvent.nonce,
            requestSentEvent.token,
            requestSentEvent.amount,
            requestSentEvent.requestVersion,
            requestSentEvent.formattedRequest,
            requestSentEvent.requestID
        );
    }
}
