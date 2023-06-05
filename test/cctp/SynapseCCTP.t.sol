// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {CCTPMessageNotReceived, IncorrectRequestLength} from "../../contracts/cctp/libs/Errors.sol";
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
            chainId: CHAINID_AVAX,
            nonce: nonce,
            token: originBurnToken,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request,
            kappa: expected.kappa
        });
        vm.prank(user);
        synapseCCTPs[DOMAIN_ETH].sendCircleToken({
            recipient: recipient,
            chainId: CHAINID_AVAX,
            burnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        assertEq(cctpSetups[DOMAIN_ETH].mintBurnToken.balanceOf(user), 0);
    }

    // ═════════════════════════════════════ TESTS: RECEIVE WITH BASE REQUEST ══════════════════════════════════════════

    function testReceiveCircleTokenBaseRequest() public {
        address destMintToken = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
        vm.expectEmit();
        emit MintAndWithdraw({
            mintRecipient: address(synapseCCTPs[DOMAIN_AVAX]),
            mintToken: destMintToken,
            amount: amount
        });
        // TODO: adjust when fees are implemented
        vm.expectEmit();
        emit CircleRequestFulfilled({
            recipient: recipient,
            mintToken: destMintToken,
            fee: 0,
            token: destMintToken,
            amount: amount,
            kappa: expected.kappa
        });
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_BASE,
            formattedRequest: expected.request
        });
        assertEq(cctpSetups[DOMAIN_AVAX].mintBurnToken.balanceOf(recipient), amount);
    }

    function testReceiveCircleTokenBaseRequestRevertTransmitterReturnsFalse() public {
        uint256 amount = 10**8;
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
        // Test all possible malformed requests: we change a lowest byte in one of the request fields:
        // originDomain, nonce, originBurnToken, amount, recipient
        for (uint256 i = 0; i < 5; ++i) {
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
        // Use Swap Request instead of the origin's Base Request
        bytes memory swapRequest = RequestLib.formatRequest({
            requestVersion: RequestLib.REQUEST_SWAP,
            baseRequest: expected.request,
            swapParams: RequestLib.formatSwapParams(address(0), 0, 0, 0, 0)
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
            swapParams: RequestLib.formatSwapParams(address(0), 0, 0, 0, 0)
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
        address destMintToken = address(cctpSetups[DOMAIN_AVAX].mintBurnToken);
        uint256 amount = 10**8;
        // TODO: adjust for fees when implemented
        address tokenOut = address(poolSetups[DOMAIN_AVAX].token);
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool: address(poolSetups[DOMAIN_AVAX].pool),
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
        vm.expectEmit();
        emit MintAndWithdraw({
            mintRecipient: address(synapseCCTPs[DOMAIN_AVAX]),
            mintToken: destMintToken,
            amount: amount
        });
        // TODO: adjust when fees are implemented
        vm.expectEmit();
        emit CircleRequestFulfilled({
            recipient: recipient,
            mintToken: destMintToken,
            fee: 0,
            token: tokenOut,
            amount: amountOut,
            kappa: expected.kappa
        });
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_SWAP,
            formattedRequest: expected.request
        });
        assertEq(poolSetups[DOMAIN_AVAX].token.balanceOf(recipient), amountOut);
    }

    function testReceiveCircleTokenSwapRequestRevertMalformedRequest() public {
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool: address(poolSetups[DOMAIN_AVAX].pool),
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
        for (uint256 i = 0; i < 5; ++i) {
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
        // pool, tokenIndexFrom, tokenIndexTo, deadline, minAmountOut
        for (uint256 i = 0; i < 5; ++i) {
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
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool: address(poolSetups[DOMAIN_AVAX].pool),
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
        uint256 amount = 10**8;
        uint256 amountOut = poolSetups[DOMAIN_AVAX].pool.calculateSwap(0, 1, amount);
        bytes memory swapParams = RequestLib.formatSwapParams({
            pool: address(poolSetups[DOMAIN_AVAX].pool),
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

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

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
