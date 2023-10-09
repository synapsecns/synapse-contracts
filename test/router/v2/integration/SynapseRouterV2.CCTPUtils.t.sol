// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTPModule} from "../../../../contracts/router/modules/bridge/SynapseCCTPModule.sol";
import {ISynapseCCTPConfig} from "../../../../contracts/cctp/interfaces/ISynapseCCTPConfig.sol";
import {RequestLib} from "../../../../contracts/cctp/libs/Request.sol";

import {Test} from "forge-std/Test.sol";

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

    function getNextAvailableNonce() internal view returns (uint64) {
        return ISynapseCCTPConfig(synapseCCTP).messageTransmitter().nextAvailableNonce();
    }

    function formatSwapParams(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 deadline,
        uint256 minAmountOut
    ) internal pure returns (bytes memory) {
        return RequestLib.formatSwapParams(tokenIndexFrom, tokenIndexTo, deadline, minAmountOut);
    }

    function formatRequest(
        uint32 requestVersion,
        uint32 originDomain,
        uint64 nonce,
        address originBurnToken,
        uint256 amount,
        address recipient,
        bytes memory swapParams
    ) internal pure returns (bytes memory) {
        return
            RequestLib.formatRequest({
                requestVersion: requestVersion,
                baseRequest: RequestLib.formatBaseRequest({
                    originDomain: originDomain,
                    nonce: nonce,
                    originBurnToken: originBurnToken,
                    amount: amount,
                    recipient: recipient
                }),
                swapParams: swapParams
            });
    }

    function getExpectedRequestID(
        bytes memory formattedRequest,
        uint32 destinationDomain,
        uint32 requestVersion
    ) internal pure returns (bytes32) {
        bytes32 requestHash = keccak256(formattedRequest);
        uint256 prefix = uint256(destinationDomain) * 2**32 + requestVersion;
        return keccak256(abi.encodePacked(prefix, requestHash));
    }

    function getRequestVersion(bool isBase) internal pure returns (uint32) {
        return isBase ? RequestLib.REQUEST_BASE : RequestLib.REQUEST_SWAP;
    }
}
