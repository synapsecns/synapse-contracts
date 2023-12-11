// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger, SynapseCCTP} from "../../../contracts/cctp/SynapseCCTP.sol";

contract SynapseCCTPHarness is SynapseCCTP {
    constructor(address tokenMessenger_) SynapseCCTP(ITokenMessenger(tokenMessenger_)) {}

    function mintCircleToken(
        bytes calldata message,
        bytes calldata signature,
        bytes32 requestID_
    ) external {
        _mintCircleToken(message, signature, requestID_);
    }

    function destinationCaller(address synapseCCTP, bytes32 requestID_) external pure returns (bytes32) {
        return _destinationCaller(synapseCCTP, requestID_);
    }

    function requestID(
        uint32 destinationDomain,
        uint32 requestVersion,
        bytes memory formattedRequest
    ) external pure returns (bytes32) {
        return _requestID(destinationDomain, requestVersion, formattedRequest);
    }
}
