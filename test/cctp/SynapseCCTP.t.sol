// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IncorrectRequestLength} from "../../contracts/cctp/libs/Errors.sol";
import {BaseCCTPTest, RequestLib} from "./BaseCCTP.t.sol";

contract SynapseCCTPTest is BaseCCTPTest {
    struct Params {
        bytes32 kappa;
        bytes request;
        bytes32 destinationCaller;
        bytes message;
    }

    function testSendCircleTokenBaseRequest() public {
        address originBurnToken = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        uint256 amount = 10**8;
        prepareUser(DOMAIN_ETH, amount);
        uint64 nonce = cctpSetups[DOMAIN_ETH].messageTransmitter.nextAvailableNonce();
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        vm.expectEmit();
        emit MessageSent(expected.message);
        vm.expectEmit();
        emit DepositForBurn({
            nonce: nonce,
            burnToken: originBurnToken,
            amount: amount,
            depositor: address(synapseCCTPs[DOMAIN_ETH]),
            mintRecipient: bytes32(uint256(uint160(address(synapseCCTPs[DOMAIN_AVAX])))),
            destinationDomain: DOMAIN_AVAX,
            destinationTokenMessenger: bytes32(uint256(uint160(address(cctpSetups[DOMAIN_AVAX].tokenMessenger)))),
            destinationCaller: expected.destinationCaller
        });
        vm.expectEmit();
        emit CircleRequestSent({
            destinationDomain: DOMAIN_AVAX,
            nonce: nonce,
            token: originBurnToken,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            request: expected.request,
            kappa: expected.kappa
        });
        vm.prank(user);
        synapseCCTPs[DOMAIN_ETH].sendCircleToken({
            recipient: recipient,
            destinationDomain: DOMAIN_AVAX,
            burnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_ETH].mintBurnToken.balanceOf(user), 0);
    }

    // ═════════════════════════════════════ TESTS: RECEIVE WITH BASE REQUEST ══════════════════════════════════════════

    function testReceiveCircleTokenBaseRequest() public {
        uint256 amount = 10**8;
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenBaseRequestRevertMalformedRequest() public {
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        checkMalformedRequests(expected, RequestLib.REQUEST_BASE);
    }

    function testReceiveCircleTokenBaseRequestRevertChangedRequestType() public {
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
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        bytes memory swapParams = RequestLib.formatSwapParams(address(0), 0, 0, 0, 0);
        // Simply adding swap params w/o changing the request type should fail when request is wrapped
        vm.expectRevert(IncorrectRequestLength.selector);
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: abi.encodePacked(expected.request, swapParams)
        });
    }

    function testReceiveCircleTokenBaseRequestRevertAddedSwapParamsChangedRequestType() public {
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        bytes memory swapParams = RequestLib.formatSwapParams(address(0), 0, 0, 0, 0);
        // Proving a valid request of another type leads to a failed destinationCaller check in MessageTransmitter
        vm.expectRevert("Invalid caller for message");
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_SWAP,
            formattedRequest: abi.encodePacked(expected.request, swapParams)
        });
    }

    // ═════════════════════════════════════ TESTS: RECEIVE WITH SWAP REQUEST ══════════════════════════════════════════

    function testReceiveCircleTokenSwapRequest() public {
        uint256 amount = 10**8;
        // TODO: adjust for fees when implemented
        address tokenOut = address(poolSetups[DOMAIN_AVAX].token);
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
        });
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: tokenOut,
            expectedAmountOut: amountOut,
            swapParams: swapParams
        });
        assertEq(poolSetups[DOMAIN_AVAX].token.balanceOf(recipient), amountOut);
    }

    function testReceiveCircleTokenSwapRequestRevertMalformedRequest() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
        });
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_SWAP,
            swapParams: swapParams
        });
        checkMalformedRequests(expected, RequestLib.REQUEST_SWAP);
    }

    function testReceiveCircleTokenSwapRequestRevertChangedRequestType() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
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
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
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
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp - 1), // deadline exceeded
            minAmountOut_: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenSwapRequestMinAmountOutNotReached() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp),
            minAmountOut_: 2 * amountOut // inflated amountOut to fail swap
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenSwapRequestTokenIndexesIdentical() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 0, // identical token indexes
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenSwapRequestTokenIndexesIncorrectOrder() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 1, // incorrect order
            tokenIndexTo_: 0,
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenSwapRequestTokenFromIndexOutOfRange() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 2, // out of range
            tokenIndexTo_: 1,
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenSwapRequestTokenToIndexOutOfRange() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool_: address(poolSetups[DOMAIN_AVAX].pool),
            tokenIndexFrom_: 0,
            tokenIndexTo_: 2, // out of range
            deadline_: uint80(block.timestamp),
            minAmountOut_: amountOut
        });
        // Swap fails, and as a result the recipient gets the minted tokens instead
        checkRequestFulfilled({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amountIn: amount,
            expectedTokenOut: address(cctpSetups[DOMAIN_AVAX].mintBurnToken),
            expectedAmountOut: amount,
            swapParams: swapParams
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function checkRequestFulfilled(
        uint32 originDomain,
        uint32 destinationDomain,
        uint256 amountIn,
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
        vm.expectEmit();
        emit MintAndWithdraw({
            mintRecipient: address(synapseCCTPs[destinationDomain]),
            mintToken: destMintToken,
            amount: amountIn
        });
        // TODO: adjust when fees are implemented
        vm.expectEmit();
        emit CircleRequestFulfilled({
            recipient: recipient,
            mintToken: destMintToken,
            fee: 0,
            token: expectedTokenOut,
            amount: expectedAmountOut,
            kappa: expected.kappa
        });
        synapseCCTPs[destinationDomain].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: requestVersion,
            formattedRequest: expected.request
        });
    }

    function checkMalformedRequests(Params memory expected, uint32 requestVersion) public {
        // Test all possible malformed requests: we change a single bit in one of the bytes
        for (uint256 i = 0; i < expected.request.length; ++i) {
            bytes memory malformedRequest = abi.encodePacked(expected.request);
            for (uint8 j = 0; j < 8; ++j) {
                // Change a single bit in request[i]
                malformedRequest[i] = expected.request[i] ^ bytes1(uint8(1) << j);
                // destinationCaller check in MessageTransmitter should fail
                vm.expectRevert("Invalid caller for message");
                synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
                    message: expected.message,
                    signature: "",
                    requestVersion: requestVersion,
                    formattedRequest: malformedRequest
                });
            }
        }
    }

    function getExpectedParams(
        uint32 originDomain,
        uint32 destinationDomain,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) public view returns (Params memory expected) {
        address originBurnToken = address(cctpSetups[originDomain].mintBurnToken);
        expected.kappa = getExpectedKappa({
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
        expected.destinationCaller = getExpectedDstCaller({
            destinationDomain: destinationDomain,
            kappa: expected.kappa
        });
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
}
