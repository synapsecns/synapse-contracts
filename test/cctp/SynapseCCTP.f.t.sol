// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CCTPMessageNotReceived} from "../../contracts/cctp/libs/Errors.sol";
import {MinimalForwarderLib} from "../../contracts/cctp/libs/MinimalForwarder.sol";
import {SynapseCCTPHarness} from "./harnesses/SynapseCCTPHarness.sol";

import {Test} from "forge-std/Test.sol";

contract FakeTokenMessenger {
    address public localMessageTransmitter;

    constructor(address localMessageTransmitter_) {
        localMessageTransmitter = localMessageTransmitter_;
    }
}

contract FakeMessageTransmitter {
    uint32 public localDomain;
    bytes public expectedMessage;
    bytes public expectedSignature;
    address public expectedCaller;

    constructor(uint32 localDomain_) {
        localDomain = localDomain_;
    }

    function setExpectedCall(
        bytes calldata message,
        bytes calldata signature,
        address expectedCaller_
    ) external {
        expectedMessage = message;
        expectedSignature = signature;
        expectedCaller = expectedCaller_;
    }

    function receiveMessage(bytes calldata message, bytes calldata signature) external view returns (bool success) {
        return
            keccak256(message) == keccak256(expectedMessage) &&
            keccak256(signature) == keccak256(expectedSignature) &&
            msg.sender == expectedCaller;
    }
}

contract SynapseCCTPFuzzTest is Test {
    SynapseCCTPHarness public synapseCCTP;
    SynapseCCTPHarness public remoteSynapseCCTP;
    FakeTokenMessenger public tokenMessenger;
    FakeMessageTransmitter public messageTransmitter;

    function setUp() public {
        messageTransmitter = new FakeMessageTransmitter(1);
        tokenMessenger = new FakeTokenMessenger(address(messageTransmitter));
        synapseCCTP = new SynapseCCTPHarness(address(tokenMessenger));
        remoteSynapseCCTP = new SynapseCCTPHarness(address(tokenMessenger));
        synapseCCTP.initialize(address(this));
        remoteSynapseCCTP.initialize(address(this));
    }

    function testRequestID(
        uint32 destinationDomain,
        uint32 requestVersion,
        bytes memory formattedRequest
    ) public {
        uint256 expectedPrefix = uint256(destinationDomain) * 2**32 + requestVersion;
        bytes32 requestHash = keccak256(formattedRequest);
        bytes32 expectedRequestID = keccak256(abi.encode(expectedPrefix, requestHash));
        assertEq(synapseCCTP.requestID(destinationDomain, requestVersion, formattedRequest), expectedRequestID);
    }

    function testDestinationCaller(bytes32 requestID) public {
        // Calculate expected destination caller for remote Synapse CCTP
        bytes32 destinationCaller = synapseCCTP.destinationCaller(address(remoteSynapseCCTP), requestID);
        // Simulate remote Synapse CCTP deploying a MinimalForwarder
        vm.prank(address(remoteSynapseCCTP));
        address forwarder = MinimalForwarderLib.deploy(requestID);
        // Check that address and bytecode match
        assertEq(abi.encode(destinationCaller), abi.encode(forwarder));
        assertEq(forwarder.code, MinimalForwarderLib.FORWARDER_BYTECODE);
    }

    function testMintCircleToken(
        bytes calldata message,
        bytes calldata signature,
        bytes32 requestID
    ) public {
        address expectedCaller = MinimalForwarderLib.predictAddress(address(remoteSynapseCCTP), requestID);
        messageTransmitter.setExpectedCall(message, signature, expectedCaller);
        // Check that mint tokens works
        remoteSynapseCCTP.mintCircleToken(message, signature, requestID);
    }

    // Sanity checks that tested mintCircleToken reverts when one of the parameters is incorrect

    function testMintCircleTokenRevertWhenIncorrectMessage() public {
        bytes memory message = "message";
        bytes memory signature = "signature";
        bytes32 requestID = "Request ID";
        address expectedCaller = MinimalForwarderLib.predictAddress(address(remoteSynapseCCTP), requestID);
        messageTransmitter.setExpectedCall("incorrect message", signature, expectedCaller);
        vm.expectRevert(CCTPMessageNotReceived.selector);
        remoteSynapseCCTP.mintCircleToken(message, signature, requestID);
    }

    function testMintCircleTokenRevertWhenIncorrectSignature() public {
        bytes memory message = "message";
        bytes memory signature = "signature";
        bytes32 requestID = "Request ID";
        address expectedCaller = MinimalForwarderLib.predictAddress(address(remoteSynapseCCTP), requestID);
        messageTransmitter.setExpectedCall(message, "incorrect signature", expectedCaller);
        vm.expectRevert(CCTPMessageNotReceived.selector);
        remoteSynapseCCTP.mintCircleToken(message, signature, requestID);
    }

    function testMintCircleTokenRevertWhenIncorrectRequestID() public {
        bytes memory message = "message";
        bytes memory signature = "signature";
        bytes32 requestID = "Request ID";
        address expectedCaller = MinimalForwarderLib.predictAddress(address(remoteSynapseCCTP), requestID);
        messageTransmitter.setExpectedCall(message, signature, expectedCaller);
        vm.expectRevert(CCTPMessageNotReceived.selector);
        remoteSynapseCCTP.mintCircleToken(message, signature, "incorrect request ID");
    }
}
