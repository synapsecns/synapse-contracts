// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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
