// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockMessageTransmitter} from "./mocks/MockMessageTransmitter.sol";
import {MockMintBurnToken} from "./mocks/MockMintBurnToken.sol";
import {MockTokenMessenger} from "./mocks/MockTokenMessenger.sol";
import {MockTokenMinter} from "./mocks/MockTokenMinter.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockDefaultPool} from "./mocks/MockDefaultPool.sol";

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

    struct PoolSetup {
        MockERC20 token;
        MockDefaultPool pool;
    }

    uint256 public constant CHAINID_ETH = 1;
    uint256 public constant CHAINID_AVAX = 43114;

    uint32 public constant DOMAIN_ETH = 0;
    uint32 public constant DOMAIN_AVAX = 1;

    uint256 public constant GAS_AIRDROP_ETH = 0;
    uint256 public constant GAS_AIRDROP_AVAX = 10**18;

    mapping(uint32 => CCTPSetup) public cctpSetups;
    mapping(uint32 => SynapseCCTP) public synapseCCTPs;
    mapping(uint32 => PoolSetup) public poolSetups;
    mapping(uint32 => uint256) public chainGasAmounts;

    address public user;
    address public recipient;
    address public owner;
    address public relayer;
    address public collector;

    function setUp() public virtual {
        user = makeAddr("User");
        recipient = makeAddr("Recipient");
        owner = makeAddr("Owner");
        relayer = makeAddr("Relayer");
        collector = makeAddr("Collector");
        deployCCTP(DOMAIN_ETH);
        deployCCTP(DOMAIN_AVAX);
        deploySynapseCCTP(DOMAIN_ETH, GAS_AIRDROP_ETH);
        deploySynapseCCTP(DOMAIN_AVAX, GAS_AIRDROP_AVAX);
        linkDomains(CHAINID_ETH, DOMAIN_ETH, CHAINID_AVAX, DOMAIN_AVAX);
        deployPool(DOMAIN_ETH);
        deployPool(DOMAIN_AVAX);
    }

    function deployCCTP(uint32 domain) public returns (CCTPSetup memory setup) {
        setup.messageTransmitter = new MockMessageTransmitter(domain);
        setup.tokenMessenger = new MockTokenMessenger(address(setup.messageTransmitter));
        setup.tokenMinter = new MockTokenMinter(address(setup.tokenMessenger));
        setup.mintBurnToken = new MockMintBurnToken(address(setup.tokenMinter));

        setup.tokenMessenger.setLocalMinter(address(setup.tokenMinter));

        cctpSetups[domain] = setup;
    }

    function deploySynapseCCTP(uint32 domain, uint256 chainGasAmount) public returns (SynapseCCTP synapseCCTP) {
        synapseCCTP = new SynapseCCTP(cctpSetups[domain].tokenMessenger);
        chainGasAmounts[domain] = chainGasAmount;
        synapseCCTP.setChainGasAmount(chainGasAmount);
        // 1 bps relayer fee, minBaseFee = 1, minSwapFee = 2, maxFee = 100
        synapseCCTP.addToken({
            symbol: "CCTP.MockC",
            token: address(cctpSetups[domain].mintBurnToken),
            relayerFee: 1 * 10**6,
            minBaseFee: 1 * 10**6,
            minSwapFee: 2 * 10**6,
            maxFee: 100 * 10**6
        });
        // Protocol fee: 50%
        synapseCCTP.setProtocolFee(5 * 10**9);
        vm.prank(relayer);
        synapseCCTP.setFeeCollector(collector);
        synapseCCTP.transferOwnership(owner);
        synapseCCTPs[domain] = synapseCCTP;
    }

    function linkDomains(
        uint256 chainIdA,
        uint32 domainA,
        uint256 chainIdB,
        uint32 domainB
    ) public {
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

        vm.startPrank(owner);
        vm.chainId(chainIdA);
        synapseCCTPs[domainA].setRemoteDomainConfig({
            remoteChainId: chainIdB,
            remoteDomain: domainB,
            remoteSynapseCCTP: address(synapseCCTPs[domainB])
        });
        vm.chainId(chainIdB);
        synapseCCTPs[domainB].setRemoteDomainConfig({
            remoteChainId: chainIdA,
            remoteDomain: domainA,
            remoteSynapseCCTP: address(synapseCCTPs[domainA])
        });
        vm.stopPrank();
    }

    function deployPool(uint32 domain) public returns (PoolSetup memory setup) {
        setup.token = new MockERC20("MockT", 6);
        address[] memory tokens = new address[](2);
        tokens[0] = address(cctpSetups[domain].mintBurnToken);
        tokens[1] = address(setup.token);
        setup.pool = new MockDefaultPool(tokens);
        // Mint some initial tokens to the pool
        cctpSetups[domain].mintBurnToken.mintPublic(address(setup.pool), 10**10);
        setup.token.mint(address(setup.pool), 10**10);
        poolSetups[domain] = setup;
        // Whitelist pool in SynapseCCTP
        vm.prank(owner);
        synapseCCTPs[domain].setCircleTokenPool(address(cctpSetups[domain].mintBurnToken), address(setup.pool));
    }

    function removeCircleTokenPool(uint32 domain) public {
        vm.prank(owner);
        synapseCCTPs[domain].setCircleTokenPool(address(cctpSetups[domain].mintBurnToken), address(0));
    }

    function disableGasAirdrops() public {
        // Disable for ETH
        chainGasAmounts[DOMAIN_ETH] = 0;
        vm.prank(owner);
        synapseCCTPs[DOMAIN_ETH].setChainGasAmount(0);
        // Disable for AVAX
        chainGasAmounts[DOMAIN_AVAX] = 0;
        vm.prank(owner);
        synapseCCTPs[DOMAIN_AVAX].setChainGasAmount(0);
    }

    function getExpectedMessage(
        uint32 originDomain,
        uint32 destinationDomain,
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
            recipient: address(cctpSetups[destinationDomain].tokenMessenger),
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
