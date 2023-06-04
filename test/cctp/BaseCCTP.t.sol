// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockMessageTransmitter} from "./mocks/MockMessageTransmitter.sol";
import {MockMintBurnToken} from "./mocks/MockMintBurnToken.sol";
import {MockTokenMessenger} from "./mocks/MockTokenMessenger.sol";
import {MockTokenMinter} from "./mocks/MockTokenMinter.sol";

import {MessageTransmitterEvents} from "../../contracts/cctp/events/MessageTransmitterEvents.sol";
import {TokenMessengerEvents} from "../../contracts/cctp/events/TokenMessengerEvents.sol";
import {MinimalForwarderLib} from "../../contracts/cctp/libs/MinimalForwarder.sol";
import {RequestLib} from "../../contracts/cctp/libs/Request.sol";
import {SynapseCCTPEvents, SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {Test} from "forge-std/Test.sol";

abstract contract BaseCCTPTest is MessageTransmitterEvents, TokenMessengerEvents, SynapseCCTPEvents, Test {
    struct CCTPSetup {
        MockMessageTransmitter messageTransmitter;
        MockMintBurnToken mintBurnToken;
        MockTokenMessenger tokenMessenger;
        MockTokenMinter tokenMinter;
    }

    uint32 public constant DOMAIN_ETH = 1;
    uint32 public constant DOMAIN_AVAX = 43114;

    mapping(uint32 => CCTPSetup) public cctpSetups;
    mapping(uint32 => SynapseCCTP) public synapseCCTPs;

    address public user;
    address public recipient;

    function setUp() public virtual {
        deployCCTP(DOMAIN_ETH);
        deployCCTP(DOMAIN_AVAX);
        deploySynapseCCTP(DOMAIN_ETH);
        deploySynapseCCTP(DOMAIN_AVAX);
        linkDomains(DOMAIN_ETH, DOMAIN_AVAX);
        user = makeAddr("User");
        recipient = makeAddr("Recipient");
    }

    function deployCCTP(uint32 domain) public returns (CCTPSetup memory setup) {
        setup.messageTransmitter = new MockMessageTransmitter(domain);
        setup.tokenMessenger = new MockTokenMessenger(address(setup.messageTransmitter));
        setup.tokenMinter = new MockTokenMinter(address(setup.tokenMessenger));
        setup.mintBurnToken = new MockMintBurnToken(address(setup.tokenMinter));

        setup.tokenMessenger.setLocalMinter(address(setup.tokenMinter));

        cctpSetups[domain] = setup;
    }

    function deploySynapseCCTP(uint32 domain) public returns (SynapseCCTP synapseCCTP) {
        synapseCCTP = new SynapseCCTP(cctpSetups[domain].tokenMessenger);
        synapseCCTPs[domain] = synapseCCTP;
    }

    function linkDomains(uint32 domainA, uint32 domainB) public {
        CCTPSetup memory setupA = cctpSetups[domainA];
        CCTPSetup memory setupB = cctpSetups[domainB];

        setupA.tokenMessenger.setRemoteTokenMessenger({
            remoteDomain: domainB,
            remoteTokenMessenger_: bytes32(uint256(uint160(address(setupB.tokenMessenger))))
        });
        setupB.tokenMessenger.setRemoteTokenMessenger({
            remoteDomain: domainA,
            remoteTokenMessenger_: bytes32(uint256(uint160(address(setupA.tokenMessenger))))
        });

        setupA.tokenMinter.setLocalToken({
            remoteDomain: domainB,
            remoteToken: bytes32(uint256(uint160(address(setupB.mintBurnToken)))),
            localToken: address(setupA.mintBurnToken)
        });
        setupB.tokenMinter.setLocalToken({
            remoteDomain: domainA,
            remoteToken: bytes32(uint256(uint160(address(setupA.mintBurnToken)))),
            localToken: address(setupB.mintBurnToken)
        });

        synapseCCTPs[domainA].setRemoteSynapseCCTP({
            remoteDomain: domainB,
            remoteSynapseCCTP_: address(synapseCCTPs[domainB])
        });
        synapseCCTPs[domainB].setRemoteSynapseCCTP({
            remoteDomain: domainA,
            remoteSynapseCCTP_: address(synapseCCTPs[domainA])
        });
    }

    function getExpectedMessage(
        uint32 originDomain,
        uint32 destinationDomain,
        address finalRecipient,
        address originBurnToken,
        uint256 amount,
        bytes32 destinationCaller
    ) public view returns (bytes memory expectedMessage) {
        bytes32 remoteSynapseCCTP = bytes32(uint256(uint160(address(synapseCCTPs[destinationDomain]))));
        bytes memory messageBody = cctpSetups[originDomain].tokenMessenger.formatTokenMessage({
            amount: amount,
            mintRecipient: remoteSynapseCCTP,
            burnToken: originBurnToken
        });
        expectedMessage = cctpSetups[originDomain].messageTransmitter.formatMessage({
            remoteDomain: originDomain,
            sender: address(cctpSetups[originDomain].tokenMessenger),
            recipient: finalRecipient,
            destinationCaller: destinationCaller,
            messageBody: messageBody
        });
    }

    function getExpectedKappa(
        uint32 originDomain,
        uint32 destinationDomain,
        address finalRecipient,
        address originBurnToken,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) public view returns (bytes32 kappa) {
        uint64 nonce = cctpSetups[originDomain].messageTransmitter.nextAvailableNonce();
        bytes memory formattedRequest = RequestLib.formatRequest({
            requestVersion: requestVersion,
            baseRequest: RequestLib.formatBaseRequest({
                originDomain: originDomain,
                nonce: nonce,
                originBurnToken: originBurnToken,
                amount: amount,
                recipient: finalRecipient
            }),
            swapParams: swapParams
        });
        bytes32 requestHash = keccak256(formattedRequest);
        uint256 prefix = uint256(destinationDomain) * 2**32 + requestVersion;
        kappa = keccak256(abi.encodePacked(prefix, requestHash));
    }

    function getExpectedDstCaller(uint32 destinationDomain, bytes32 kappa)
        public
        view
        returns (bytes32 destinationCaller)
    {
        address dstCaller = MinimalForwarderLib.predictAddress({
            deployer: address(synapseCCTPs[destinationDomain]),
            salt: kappa
        });
        destinationCaller = bytes32(uint256(uint160(dstCaller)));
    }

    function getExpectedRequest(
        uint32 originDomain,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) public view returns (bytes memory expectedRequest) {
        expectedRequest = RequestLib.formatRequest({
            requestVersion: requestVersion,
            baseRequest: RequestLib.formatBaseRequest({
                originDomain: originDomain,
                nonce: cctpSetups[originDomain].messageTransmitter.nextAvailableNonce(),
                originBurnToken: address(cctpSetups[DOMAIN_ETH].mintBurnToken),
                amount: amount,
                recipient: recipient
            }),
            swapParams: swapParams
        });
    }
}
