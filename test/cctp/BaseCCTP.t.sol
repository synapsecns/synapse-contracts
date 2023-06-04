// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockMessageTransmitter} from "./mocks/MockMessageTransmitter.sol";
import {MockMintBurnToken} from "./mocks/MockMintBurnToken.sol";
import {MockTokenMessenger} from "./mocks/MockTokenMessenger.sol";
import {MockTokenMinter} from "./mocks/MockTokenMinter.sol";

import {SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {Test} from "forge-std/Test.sol";

abstract contract BaseCCTPTest is Test {
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

    function setUp() public virtual {
        deployCCTP(DOMAIN_ETH);
        deployCCTP(DOMAIN_AVAX);
        linkDomains(DOMAIN_ETH, DOMAIN_AVAX);
        deploySynapseCCTP(DOMAIN_ETH);
        deploySynapseCCTP(DOMAIN_AVAX);
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
    }
}
