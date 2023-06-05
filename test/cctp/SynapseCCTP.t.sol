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
            token: destMintToken,
            amount: amount,
            fee: 0,
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

    function testReceiveCircleTokenBaseRequestRevertMalformedRequest() public {
        uint256 amount = 10**8;
        Params memory expected = getExpectedParams({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            amount: amount,
            requestVersion: RequestLib.REQUEST_BASE,
            swapParams: ""
        });
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
        // Proving a valid request of another type leads to a faild destinationCaller check in MessageTransmitter
        vm.expectRevert("Invalid caller for message");
        synapseCCTPs[DOMAIN_AVAX].receiveCircleToken({
            message: expected.message,
            signature: "",
            requestVersion: RequestLib.REQUEST_SWAP,
            formattedRequest: abi.encodePacked(expected.request, swapParams)
        });
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
