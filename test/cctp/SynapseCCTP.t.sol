// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    CCTPIncorrectChainId,
    CCTPIncorrectDomain,
    CCTPMessageNotReceived,
    CCTPTokenNotFound,
    CCTPZeroAddress,
    CCTPZeroAmount,
    RemoteCCTPDeploymentNotSet,
    IncorrectRequestLength
} from "../../contracts/cctp/libs/Errors.sol";
import {BaseCCTPTest, RequestLib, SynapseCCTP} from "./BaseCCTP.t.sol";

import {MockRouter} from "./mocks/MockRouter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract SynapseCCTPTest is BaseCCTPTest {
    struct Params {
        bytes32 requestID;
        bytes request;
        bytes32 mintRecipient;
        bytes32 destinationCaller;
        bytes32 destinationTokenMessenger;
        bytes message;
    }

    function testConstructorSetsOwner() public {
        SynapseCCTP cctp = new SynapseCCTP(cctpSetups[DOMAIN_ETH].tokenMessenger, owner);
        assertEq(address(cctp.owner()), owner);
    }

    function testSendCircleTokenBaseRequest() public {
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        checkRequestSent({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            destinationChainId: CHAINID_AVAX,
            amount: amount,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_ETH].mintBurnToken.balanceOf(user), 0);
    }

    function testSendCircleTokenBaseRequestUsingRouter() public {
        uint64 nonce = cctpSetups[DOMAIN_ETH].messageTransmitter.nextAvailableNonce();
        MockRouter router = new MockRouter(address(synapseCCTPs[DOMAIN_ETH]));
        uint256 amount = 10**8;
        CCTPSetup memory setup = cctpSetups[DOMAIN_ETH];
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        setup.mintBurnToken.mintPublic(user, amount);
        vm.prank(user);
        setup.mintBurnToken.approve(address(router), amount);
        vm.expectEmit();
        emit CircleRequestSent({
            chainId: CHAINID_AVAX,
            sender: user,
            nonce: nonce,
            token: address(setup.mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request,
            requestID: expected.requestID
        });
        // prank both msg.sender and tx.origin
        vm.prank(user, user);
        router.sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_AVAX,
            burnToken: address(setup.mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
    }

    function testSendCircleTokenBaseRequestWithLowAllowance() public {
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        // Imagine a scenario where SynapseCCTP somehow issued a low spending allowance to TokenMessenger
        address synCCTP = address(synapseCCTPs[DOMAIN_ETH]);
        address tokenMessenger = address(cctpSetups[DOMAIN_ETH].tokenMessenger);
        address originBurnToken = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        vm.prank(synCCTP);
        cctpSetups[DOMAIN_ETH].mintBurnToken.approve(tokenMessenger, amount - 1);
        require(
            cctpSetups[DOMAIN_ETH].mintBurnToken.allowance(synCCTP, tokenMessenger) == amount - 1,
            "Failed to set low allowance"
        );
        // Should be able to reset the allowance to zero and then set it to infinity
        vm.expectCall(originBurnToken, abi.encodeWithSelector(IERC20.approve.selector, tokenMessenger, 0));
        vm.expectCall(
            originBurnToken,
            abi.encodeWithSelector(IERC20.approve.selector, tokenMessenger, type(uint256).max)
        );
        vm.prank(user);
        synapseCCTPs[DOMAIN_ETH].sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_AVAX,
            burnToken: originBurnToken,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_ETH].mintBurnToken.balanceOf(user), 0);
    }

    function testSendCircleTokenBaseRequestRevertsWhenPaused() public {
        pauseSending(DOMAIN_ETH);
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        vm.expectRevert("Pausable: paused");
        vm.prank(user);
        synapseCCTPs[DOMAIN_ETH].sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_AVAX,
            burnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
    }

    function testSendCircleTokenSwapRequest() public {
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: 4321,
            minAmountOut: 9876543210
        });
        checkRequestSent({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            destinationChainId: CHAINID_AVAX,
            amount: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_ETH].mintBurnToken.balanceOf(user), 0);
    }

    function testSendCircleTokenSwapRequestRevertsWhenPaused() public {
        pauseSending(DOMAIN_ETH);
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: 4321,
            minAmountOut: 9876543210
        });
        vm.expectRevert("Pausable: paused");
        vm.prank(user);
        synapseCCTPs[DOMAIN_ETH].sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_AVAX,
            burnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_SWAP,
            swapParams: swapParams
        });
    }

    function testSendCircleTokenRevertsWhenRemoteDeploymentNotSet() public {
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        vm.expectRevert(RemoteCCTPDeploymentNotSet.selector);
        vm.prank(user);
        synapseCCTPs[DOMAIN_ETH].sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_AVAX + 1, // unknown chainId
            burnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
    }

    function testSendCircleTokenRevertsWhenTokenNotSupported() public {
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        vm.expectRevert(CCTPTokenNotFound.selector);
        vm.prank(user);
        // Use ETH token in AVAX SynapseCCTP
        synapseCCTPs[DOMAIN_AVAX].sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_ETH,
            burnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetLocalToken() public {
        address ethToken = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address avaxToken = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        assertEq(synapseCCTPs[DOMAIN_ETH].getLocalToken({remoteDomain: DOMAIN_AVAX, remoteToken: avaxToken}), ethToken);
        assertEq(synapseCCTPs[DOMAIN_AVAX].getLocalToken({remoteDomain: DOMAIN_ETH, remoteToken: ethToken}), avaxToken);
    }

    function testGetLocalTokenRevertsForUnknownToken() public {
        address ethToken = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address avaxToken = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        vm.expectRevert(CCTPTokenNotFound.selector);
        synapseCCTPs[DOMAIN_ETH].getLocalToken({remoteDomain: DOMAIN_AVAX, remoteToken: ethToken});
        vm.expectRevert(CCTPTokenNotFound.selector);
        synapseCCTPs[DOMAIN_AVAX].getLocalToken({remoteDomain: DOMAIN_ETH, remoteToken: avaxToken});
    }

    // ═════════════════════════════════════ TESTS: RECEIVE WITH BASE REQUEST ══════════════════════════════════════════

    function testReceiveCircleTokenBaseRequest() public {
        uint256 amount = 10**8;
        uint256 baseFeeAmount = 10**6;
        uint256 expectedAmountOut = amount - baseFeeAmount;
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: baseFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: expectedAmountOut,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), expectedAmountOut);
    }

    function testReceiveCircleTokenBaseRequestSucceedsWhenPaused() public {
        // Pause both sides just in case
        pauseSending(DOMAIN_AVAX);
        pauseSending(DOMAIN_ETH);
        uint256 amount = 10**8;
        uint256 baseFeeAmount = 10**6;
        uint256 expectedAmountOut = amount - baseFeeAmount;
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: baseFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: expectedAmountOut,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), expectedAmountOut);
    }

    function testReceiveCircleTokenBaseRequestRevertTransmitterReturnsFalse() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        uint256 baseFeeAmount = 10**6;
        uint256 expectedAmountOut = amount - baseFeeAmount;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        // Let's imagine that SynapseCCTP has required amount of tokens prior to the call
        cctpSetups[DOMAIN_AVAX].mintBurnToken.mintPublic(address(synapseCCTPs[DOMAIN_AVAX]), amount);
        vm.expectRevert(CCTPMessageNotReceived.selector);
        // Pass 1-byte signature to make MessageTransmitter return false
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: new bytes(1),
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request
        });
        // Transfer out the tokens that were minted
        vm.prank(address(synapseCCTPs[DOMAIN_AVAX]));
        cctpSetups[DOMAIN_AVAX].mintBurnToken.transfer(address(1), amount);
        // Should be completed when the Transmitter returns true
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), expectedAmountOut);
    }

    function testReceiveCircleTokenBaseRequestRevertMalformedRequest() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        // Test all possible malformed requests: we change a lowest byte in one of the request fields:
        // originDomain, nonce, originBurnToken, amount, recipient
        for (uint256 i = 0; i < RequestLib.REQUEST_BASE_LENGTH / 32; ++i) {
            bytes memory malformedRequest = abi.encodePacked(expected.request);
            // Figure out the byte index of the field we want to change
            // request[byteIndex] is the lowest byte of the field `i`
            uint256 byteIndex = 32 * i + 31;
            for (uint8 j = 0; j < 8; ++j) {
                // Change j-th bit in request[byteIndex], leaving others unchanged
                malformedRequest[byteIndex] = expected.request[byteIndex] ^ bytes1(uint8(1) << j);
                // destinationCaller check in MessageTransmitter should fail
                vm.expectRevert("Invalid caller for message");
                synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
                    message: expected.message,
                    signature: "",
                    requestVersion: RequestLib.REQUEST_BASE,
                    formattedRequest: malformedRequest
                });
            }
        }
    }

    function testReceiveCircleTokenBaseRequestRevertChangedRequestType() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        // Simply changing the request type should fail when request is wrapped
        vm.expectRevert(IncorrectRequestLength.selector);
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_SWAP,
            formattedRequest: expected.request
        });
    }

    function testReceiveCircleTokenBaseRequestRevertAddedSwapParams() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        // Use Swap Request instead of the origin's Base Request
        bytes memory swapRequest = RequestLib.formatRequest({
            requestVersion: RequestLib.REQUEST_SWAP,
            baseRequest: expected.request,
            swapParams: RequestLib.formatSwapParams(0, 0, 0, 0)
        });
        // Simply adding swap params w/o changing the request type should fail when request is wrapped
        vm.expectRevert(IncorrectRequestLength.selector);
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: swapRequest
        });
    }

    function testReceiveCircleTokenBaseRequestRevertAddedSwapParamsChangedRequestType() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        // Use Swap Request instead of the origin's Base Request
        bytes memory swapRequest = RequestLib.formatRequest({
            requestVersion: RequestLib.REQUEST_SWAP,
            baseRequest: expected.request,
            swapParams: RequestLib.formatSwapParams(0, 0, 0, 0)
        });
        // Proving a valid request of another type leads to a failed destinationCaller check in MessageTransmitter
        vm.expectRevert("Invalid caller for message");
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_SWAP,
            formattedRequest: swapRequest
        });
    }

    // ═════════════════════════════════════ TESTS: RECEIVE WITH SWAP REQUEST ══════════════════════════════════════════

    function testReceiveCircleTokenSwapRequest() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        address tokenOut = address(poolSetups[DOMAIN_AVAX].token);
        uint256 expectedAmountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: expectedAmountOut
        });
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: tokenOut,
            expectedAmountOut: expectedAmountOut,
            swapParams: swapParams
        });
        assertEq(poolSetups[DOMAIN_AVAX].token.balanceOf(recipient), expectedAmountOut);
    }

    function testReceiveCircleTokenSwapRequestSucceedsWhenPaused() public {
        // Pause both sides just in case
        pauseSending(DOMAIN_AVAX);
        pauseSending(DOMAIN_ETH);
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        address tokenOut = address(poolSetups[DOMAIN_AVAX].token);
        uint256 expectedAmountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: expectedAmountOut
        });
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: tokenOut,
            expectedAmountOut: expectedAmountOut,
            swapParams: swapParams
        });
        assertEq(poolSetups[DOMAIN_AVAX].token.balanceOf(recipient), expectedAmountOut);
    }

    function testReceiveCircleTokenSwapRequestRevertMalformedRequest() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        Params memory expectedBase = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_SWAP,
            swapParams: swapParams
        });
        // Test all possible malformed base requests: we change a lowest byte in one of the request fields:
        // originDomain, nonce, originBurnToken, amount, recipient
        for (uint256 i = 0; i < RequestLib.REQUEST_BASE_LENGTH / 32; ++i) {
            bytes memory malformedRequest = abi.encodePacked(expectedBase.request);
            // Figure out the byte index of the field we want to change
            // request[byteIndex] is the lowest byte of the field `i`
            uint256 byteIndex = 32 * i + 31;
            for (uint8 j = 0; j < 8; ++j) {
                // Change j-th bit in request[byteIndex], leaving others unchanged
                malformedRequest[byteIndex] = expectedBase.request[byteIndex] ^ bytes1(uint8(1) << j);
                bytes memory malformedSwapRequest = RequestLib.formatRequest({
                    requestVersion: RequestLib.REQUEST_SWAP,
                    baseRequest: malformedRequest,
                    swapParams: swapParams
                });
                // destinationCaller check in MessageTransmitter should fail
                vm.expectRevert("Invalid caller for message");
                synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
                    message: expected.message,
                    signature: "",
                    requestVersion: RequestLib.REQUEST_SWAP,
                    formattedRequest: malformedSwapRequest
                });
            }
        }
        // Test all possible malformed swap params: we change a lowest byte in one of the request fields:
        // tokenIndexFrom, tokenIndexTo, deadline, minAmountOut
        for (uint256 i = 0; i < RequestLib.SWAP_PARAMS_LENGTH / 32; ++i) {
            bytes memory malformedSwapParams = abi.encodePacked(swapParams);
            // Figure out the byte index of the field we want to change
            // swapParams[byteIndex] is the lowest byte of the field `i`
            uint256 byteIndex = 32 * i + 31;
            for (uint8 j = 0; j < 8; ++j) {
                // Change j-th bit in swapParams[byteIndex], leaving others unchanged
                malformedSwapParams[byteIndex] = swapParams[byteIndex] ^ bytes1(uint8(1) << j);
                bytes memory malformedSwapRequest = RequestLib.formatRequest({
                    requestVersion: RequestLib.REQUEST_SWAP,
                    baseRequest: expectedBase.request,
                    swapParams: malformedSwapParams
                });

                // destinationCaller check in MessageTransmitter should fail
                vm.expectRevert("Invalid caller for message");
                synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
                    message: expected.message,
                    signature: "",
                    requestVersion: RequestLib.REQUEST_SWAP,
                    formattedRequest: malformedSwapRequest
                });
            }
        }
    }

    function testReceiveCircleTokenSwapRequestRevertChangedRequestType() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_SWAP,
            swapParams: swapParams
        });
        // Simply changing the request type should fail when request is wrapped
        vm.expectRevert(IncorrectRequestLength.selector);
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request
        });
    }

    function testReceiveCircleTokenSwapRequestRevertChangedRequestTypeRemovedSwapParams() public {
        disableGasAirdrops();
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_SWAP,
            swapParams: swapParams
        });
        Params memory expectedBase = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        // Proving a valid request of another type leads to a failed destinationCaller check in MessageTransmitter
        vm.expectRevert("Invalid caller for message");
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expectedBase.request
        });
    }

    // ══════════════════════════════ TESTS: RECEIVE WITH SWAP REQUEST (SWAP FAILED) ═══════════════════════════════════

    function testReceiveCircleTokenSwapRequestDeadlineExceeded() public {
        // Adjust block.timestamp
        vm.warp(123456789);
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp - 1, // deadline exceeded
            minAmountOut: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestMinAmountOutNotReached() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: 2 * amountOut // inflated amountOut to fail swap
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestTokenIndexesIdentical() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 0, // identical token indexes
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestTokenIndexesIncorrectOrder() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 1, // incorrect order
            tokenIndexTo: 0,
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestTokenFromIndexOutOfRange() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 2, // out of range
            tokenIndexTo: 1,
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestTokenToIndexOutOfRange() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount - swapFeeAmount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 2, // out of range
            deadline: block.timestamp,
            minAmountOut: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestSwapRequestZeroValues() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 0,
            deadline: 0,
            minAmountOut: 0
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    function testReceiveCircleTokenSwapRequestNoWhitelistedPool() public {
        uint256 amount = 10**8;
        uint256 swapFeeAmount = 2 * 10**6;
        bytes memory swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: type(uint256).max,
            minAmountOut: 0
        });
        removeCircleTokenPool(DOMAIN_AVAX);
        // No Swap is available, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedFeeAmount: swapFeeAmount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount - swapFeeAmount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount - swapFeeAmount);
    }

    // ══════════════════════════════════════════ TESTS: WITHDRAWING FEES ══════════════════════════════════════════════

    function accumulateFees() public {
        disableGasAirdrops();
        uint256 amount = 10**8; // baseFee is 10**6
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        address unregisteredRelayer = makeAddr("UnregisteredRelayer");
        vm.prank(unregisteredRelayer);
        // Full fee should go to the protocol: 10**6
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request
        });
        amount = 2 * 10**10; // baseFee is 2 * 10**6
        expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        vm.prank(relayer);
        // Half of the fee should go to the relayer: 10**6
        // The other half should go to the protocol: 10**6
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request
        });
        // Total protocol fees: 2 * 10**6
        // Total relayer fees: 1 * 10**6
    }

    function testAccumulateFees() public {
        address token = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        accumulateFees();
        assertEq(synapseCCTPs[DOMAIN_AVAX].accumulatedFees(address(0), token), 2 * 10**6);
        assertEq(synapseCCTPs[DOMAIN_AVAX].accumulatedFees(collector, token), 1 * 10**6);
    }

    function testWithdrawProtocolFeesResetsAccumulatedFees() public {
        address token = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        accumulateFees();
        vm.prank(owner);
        synapseCCTPs[DOMAIN_AVAX].withdrawProtocolFees(token);
        assertEq(synapseCCTPs[DOMAIN_AVAX].accumulatedFees(address(0), token), 0);
    }

    function testWithdrawProtocolFeesTransfersToken() public {
        accumulateFees();
        vm.prank(owner);
        synapseCCTPs[DOMAIN_AVAX].withdrawProtocolFees(address(cctpSetups[DOMAIN_AVAX].mintBurnToken));
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(owner), 2 * 10**6);
    }

    function testWithdrawProtocolFeesRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        synapseCCTPs[DOMAIN_AVAX].withdrawProtocolFees(address(cctpSetups[DOMAIN_AVAX].mintBurnToken));
    }

    function testWithdrawProtocolFeesRevertsWhenZeroAmount() public {
        vm.expectRevert(CCTPZeroAmount.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_AVAX].withdrawProtocolFees(address(cctpSetups[DOMAIN_AVAX].mintBurnToken));
    }

    function testWithdrawRelayerFeesResetsAccumulatedFees() public {
        address token = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        accumulateFees();
        vm.prank(collector);
        synapseCCTPs[DOMAIN_AVAX].withdrawRelayerFees(token);
        assertEq(synapseCCTPs[DOMAIN_AVAX].accumulatedFees(collector, token), 0);
    }

    function testWithdrawRelayerFeesTransfersToken() public {
        accumulateFees();
        vm.prank(collector);
        synapseCCTPs[DOMAIN_AVAX].withdrawRelayerFees(address(cctpSetups[DOMAIN_AVAX].mintBurnToken));
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(collector), 1 * 10**6);
    }

    function testWithdrawRelayerFeesRevertsWhenZeroAmount() public {
        vm.expectRevert(CCTPZeroAmount.selector);
        vm.prank(collector);
        synapseCCTPs[DOMAIN_AVAX].withdrawRelayerFees(address(cctpSetups[DOMAIN_AVAX].mintBurnToken));
    }

    // ═══════════════════════════════════════ TESTS: SETTING REMOTE CONFIG ════════════════════════════════════════════

    function testSetRemoteDomainConfigSetsConfig() public {
        vm.chainId(CHAINID_ETH);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setRemoteDomainConfig({
            remoteChainId: 10,
            remoteDomain: 2,
            remoteSynapseCCTP: address(42)
        });
        (uint32 domain, address synapseCCTP) = synapseCCTPs[DOMAIN_ETH].remoteDomainConfig(10);
        assertEq(domain, 2);
        assertEq(synapseCCTP, address(42));
    }

    function testSetRemoteDomainConfigRevertsWhenCallerNotOwner(address caller) public {
        vm.chainId(CHAINID_ETH);
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        synapseCCTPs[DOMAIN_ETH].setRemoteDomainConfig({
            remoteChainId: 10,
            remoteDomain: 2,
            remoteSynapseCCTP: address(42)
        });
    }

    function testSetRemoteDomainConfigRevertsWhenRemoteChainIdZero() public {
        vm.chainId(CHAINID_ETH);
        vm.expectRevert(CCTPIncorrectChainId.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setRemoteDomainConfig({
            remoteChainId: 0,
            remoteDomain: 2,
            remoteSynapseCCTP: address(42)
        });
    }

    function testSetRemoteDomainConfigRevertsWhenRemoteChainIdEqualsLocal() public {
        vm.chainId(CHAINID_ETH);
        vm.expectRevert(CCTPIncorrectChainId.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setRemoteDomainConfig({
            remoteChainId: CHAINID_ETH,
            remoteDomain: 2,
            remoteSynapseCCTP: address(42)
        });
    }

    function testSetRemoteDomainConfigRevertsWhenRemoteDomainEqualsLocal() public {
        vm.chainId(CHAINID_ETH);
        vm.expectRevert(CCTPIncorrectDomain.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setRemoteDomainConfig({
            remoteChainId: 10,
            remoteDomain: DOMAIN_ETH,
            remoteSynapseCCTP: address(42)
        });
    }

    function testSetRemoteDomainConfigRevertsWhenRemoteDomainZeroChainIdNotOne() public {
        vm.chainId(CHAINID_AVAX);
        vm.expectRevert(CCTPIncorrectDomain.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_AVAX].setRemoteDomainConfig({
            remoteChainId: 10,
            remoteDomain: 0,
            remoteSynapseCCTP: address(42)
        });
    }

    function testSetRemoteDomainConfigRevertsWhenRemoteDomainNotZeroChainIdOne() public {
        vm.chainId(CHAINID_AVAX);
        vm.expectRevert(CCTPIncorrectDomain.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_AVAX].setRemoteDomainConfig({
            remoteChainId: CHAINID_ETH,
            remoteDomain: 2,
            remoteSynapseCCTP: address(42)
        });
    }

    function testSetRemoteDomainConfigRevertsWhenRemoteSynapseCCTPZero() public {
        vm.chainId(CHAINID_ETH);
        vm.expectRevert(CCTPZeroAddress.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setRemoteDomainConfig({
            remoteChainId: 10,
            remoteDomain: 2,
            remoteSynapseCCTP: address(0)
        });
    }

    // ══════════════════════════════════════ TESTS: SETTING LIQUIDITY POOLS ═══════════════════════════════════════════

    function testSetCircleTokenPoolSetsPool() public {
        address token = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setCircleTokenPool(token, address(42));
        assertEq(synapseCCTPs[DOMAIN_ETH].circleTokenPool(token), address(42));
    }

    function testSetCircleTokenPoolRevertsWhenCallerNotOwner(address caller) public {
        address token = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        synapseCCTPs[DOMAIN_ETH].setCircleTokenPool(token, address(42));
    }

    function testSetCircleTokenPoolRevertsWhenTokenNotFound() public {
        address token = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        vm.expectRevert(CCTPTokenNotFound.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setCircleTokenPool(token, address(42));
    }

    function testSetCircleTokenPoolRevertsWhenTokenZero() public {
        vm.expectRevert(CCTPZeroAddress.selector);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setCircleTokenPool(address(0), address(42));
    }

    // ═══════════════════════════════════════════ TESTS: PAUSE TOGGLING ═══════════════════════════════════════════════

    function testPauseByOwner() public {
        pauseSending(DOMAIN_ETH);
        assertTrue(synapseCCTPs[DOMAIN_ETH].paused());
    }

    function testPauseRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        synapseCCTPs[DOMAIN_ETH].pauseSending();
    }

    function testUnpauseByOwner() public {
        pauseSending(DOMAIN_ETH);
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].unpauseSending();
        assertFalse(synapseCCTPs[DOMAIN_ETH].paused());
    }

    function testUnpauseRevertsWhenCallerNotOwner(address caller) public {
        pauseSending(DOMAIN_ETH);
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        synapseCCTPs[DOMAIN_ETH].unpauseSending();
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function checkRequestSent(
        uint32 originDomain,
        uint32 destinationDomain,
        uint256 destinationChainId,
        uint256 amount,
        bytes memory swapParams
    ) public {
        address originBurnToken = address(cctpSetups[originDomain].mintBurnToken);
        uint32 requestVersion = swapParams.length == 0 ? RequestLib.REQUEST_BASE : RequestLib.REQUEST_SWAP;
        uint64 nonce = cctpSetups[originDomain].messageTransmitter.nextAvailableNonce();
        Params memory expected = getExpectedParams({
            originDomain: originDomain,
            destinationDomain: destinationDomain,
            amount: amount,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
        vm.expectEmit();
        emit MessageSent(expected.message);
        vm.expectEmit();
        emit DepositForBurn({
            nonce: nonce,
            burnToken: originBurnToken,
            amount: amount,
            depositor: address(synapseCCTPs[originDomain]),
            mintRecipient: expected.mintRecipient,
            destinationDomain: destinationDomain,
            destinationTokenMessenger: expected.destinationTokenMessenger,
            destinationCaller: expected.destinationCaller
        });
        vm.expectEmit();
        emit CircleRequestSent({
            chainId: destinationChainId,
            sender: user,
            nonce: nonce,
            token: originBurnToken,
            amount: amount,
            requestVersion: requestVersion,
            formattedRequest: expected.request,
            requestID: expected.requestID
        });
        // prank both msg.sender and tx.origin
        vm.prank(user, user);
        synapseCCTPs[originDomain].sendCircleToken({
            recipient: recipient,
            chainId: destinationChainId,
            burnToken: originBurnToken,
            amount: amount,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
    }

    function checkRequestFulfilled(
        uint32 originDomain,
        uint32 destinationDomain,
        uint256 amountIn,
        uint256 expectedFeeAmount,
        address expectedTokenOut,
        uint256 expectedAmountOut,
        bytes memory swapParams
    ) public {
        address destMintToken = address(cctpSetups[destinationDomain].mintBurnToken);
        uint32 requestVersion = swapParams.length == 0 ? RequestLib.REQUEST_BASE : RequestLib.REQUEST_SWAP;
        Params memory expected = getExpectedParams({
            originDomain: originDomain,
            destinationDomain: destinationDomain,
            amount: amountIn,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
        assertFalse(synapseCCTPs[destinationDomain].isRequestFulfilled(expected.requestID));
        deal(relayer, chainGasAmounts[destinationDomain]);
        vm.expectEmit();
        emit MintAndWithdraw({
            mintRecipient: address(synapseCCTPs[destinationDomain]),
            mintToken: destMintToken,
            amount: amountIn
        });
        vm.expectEmit();
        emit CircleRequestFulfilled({
            originDomain: originDomain,
            recipient: recipient,
            mintToken: destMintToken,
            fee: expectedFeeAmount,
            token: expectedTokenOut,
            amount: expectedAmountOut,
            requestID: expected.requestID
        });
        vm.prank(relayer);
        synapseCCTPs[destinationDomain].receiveCircleToken{value: chainGasAmounts[destinationDomain]}({
            message: expected.message,
            signature: "",
            requestVersion: requestVersion,
            formattedRequest: expected.request
        });
        assertTrue(synapseCCTPs[destinationDomain].isRequestFulfilled(expected.requestID));
        assertEq(recipient.balance, chainGasAmounts[destinationDomain]);
        checkAccumulatedRelayerFee(destinationDomain, expectedFeeAmount);
    }

    function checkAccumulatedRelayerFee(uint32 domain, uint256 expectedFeeAmount) public {
        address token = address(cctpSetups[domain].mintBurnToken);
        // Protocol fee is 50% of the total fee in this setup
        uint256 protocolFeeAmount = expectedFeeAmount / 2;
        // Remainder of the fee goes to the relayer's collector
        uint256 relayerFeeAmount = expectedFeeAmount - protocolFeeAmount;
        assertEq(synapseCCTPs[domain].accumulatedFees(address(0), token), protocolFeeAmount);
        assertEq(synapseCCTPs[domain].accumulatedFees(collector, token), relayerFeeAmount);
    }

    function getExpectedParams(
        uint32 originDomain,
        uint32 destinationDomain,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) public view returns (Params memory expected) {
        address originBurnToken = address(cctpSetups[originDomain].mintBurnToken);
        expected.requestID = getExpectedrequestID({
            originDomain: originDomain,
            destinationDomain: destinationDomain,
            finalRecipient: recipient,
            originBurnToken: originBurnToken,
            amount: amount,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
        expected.request = getExpectedRequest({
            originDomain: originDomain,
            amount: amount,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
        expected.mintRecipient = bytes32(uint256(uint160(address(synapseCCTPs[destinationDomain]))));
        expected.destinationCaller = getExpectedDstCaller({
            destinationDomain: destinationDomain,
            requestID: expected.requestID
        });
        expected.destinationTokenMessenger = bytes32(
            uint256(uint160(address(cctpSetups[destinationDomain].tokenMessenger)))
        );
        expected.message = getExpectedMessage({
            originDomain: originDomain,
            destinationDomain: destinationDomain,
            originBurnToken: originBurnToken,
            amount: amount,
            destinationCaller: expected.destinationCaller
        });
    }

    function prepareUser(uint32 originDomain, uint256 amount) public {
        CCTPSetup memory setup = cctpSetups[originDomain];
        setup.mintBurnToken.mintPublic(user, amount);
        vm.prank(user);
        setup.mintBurnToken.approve(address(synapseCCTPs[originDomain]), amount);
    }

    function pauseSending(uint32 domain) public {
        vm.prank(owner);
        synapseCCTPs[domain].pauseSending();
    }
}
