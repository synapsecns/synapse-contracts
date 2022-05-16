pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import "../../contracts/messaging/MessageBus.sol";
import "../../contracts/messaging/GasFeePricing.sol";
import "../../contracts/messaging/AuthVerifier.sol";
import "../../contracts/messaging/apps/PingPong.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract PingPongTest is Test {
    Utilities internal utils;
    address payable[] internal users;
    // Chain A 1000
    uint256 chainA = 1000;
    MessageBus public messageBusChainA;
    PingPong public pingPongChainA;
    GasFeePricing public gasFeePricingChainA;
    AuthVerifier public authVerifierChainA;

    // Chain B 2000
    uint256 chainB = 2000;
    MessageBus public messageBusChainB;
    PingPong public pingPongChainB;
    GasFeePricing public gasFeePricingChainB;
    AuthVerifier public authVerifierChainB;

    bytes32 public pingPongChainABytes;

    bytes32 public pingPongChainBBytes;

    address payable public node;

    event MessageSent(
        address indexed sender,
        uint256 srcChainID,
        bytes32 receiver,
        uint256 indexed dstChainId,
        bytes message,
        uint64 nonce,
        bytes options,
        uint256 fee,
        bytes32 indexed messageId
    );

    event Executed(
        bytes32 msgId,
        MessageBus.TxStatus status,
        address indexed _dstAddress,
        uint64 srcChainId,
        uint64 srcNonce
    );

    function setUp() public {
        gasFeePricingChainA = new GasFeePricing();
        gasFeePricingChainB = new GasFeePricing();
        utils = new Utilities();
        users = utils.createUsers(10);
        node = users[0];
        vm.label(node, "Node");
        authVerifierChainA = new AuthVerifier(node);
        authVerifierChainB = new AuthVerifier(node);
        messageBusChainA = new MessageBus(
            address(gasFeePricingChainA),
            address(authVerifierChainA)
        );
        messageBusChainB = new MessageBus(
            address(gasFeePricingChainB),
            address(authVerifierChainB)
        );
        pingPongChainA = new PingPong(address(messageBusChainA));
        vm.label(address(pingPongChainA), "PingChainA");
        pingPongChainB = new PingPong(address(messageBusChainB));
        vm.label(address(pingPongChainB), "PingChainB");
        pingPongChainABytes = utils.addressToBytes32(address(pingPongChainA));
        pingPongChainBBytes = utils.addressToBytes32(address(pingPongChainB));
        vm.deal(address(pingPongChainA), 100 ether);
        vm.deal(address(pingPongChainB), 100 ether);
        gasFeePricingChainA.setCostPerChain(
            chainB,
            30000000000,
            25180000000000000
        );
        gasFeePricingChainB.setCostPerChain(
            chainA,
            30000000000,
            25180000000000000
        );
    }

    // function testPingPongE2E() public {
    //     // Chain A - 1000 chain ID. Call ping, message gets sent, processed, and event gets emitted.
    //     vm.chainId(chainA);
    //     pingPongChainA.ping(chainB, address(pingPongChainB), 0);
    //     // TODO: Check that fee was transferred & enforced on MsgBus
    //     // Ping hit, event emitted, move to next chain,
    //     vm.startPrank(address(node));
    //     vm.chainId(2000);
    //     // Relay tx construction
    //     bytes32 firstMessageId = messageBusChainB.computeMessageId(chainA, pingPongChainABytes, address(pingPongChainB), 0, abi.encode(0));
    //     // Nodes execute first message with first ID, successful
    //     messageBusChainB.executeMessage(chainA, pingPongChainABytes, address(pingPongChainB), 200000, 0, abi.encode(0), firstMessageId);
    //     console.log(pingPongChainB.numPings());
    //     vm.chainId(1000);
    //     bytes32 secondMessageId = messageBusChainA.computeMessageId(chainB, pingPongChainBBytes, address(pingPongChainA), 0, abi.encode(2));
    //     messageBusChainA.executeMessage(chainB, pingPongChainBBytes, address(pingPongChainA), 200000, 0, abi.encode(2), secondMessageId);
    //     console.log(pingPongChainA.numPings());
    //     // gets to 3 pings
    // }

    //  failure cases to implement

    // // try some differing cases of submission, they revert
    // // submit same exact transaction as original executeMessage
    // vm.expectRevert(bytes("Message already executed"));
    // messageBusChainB.executeMessage(chainA, pingPongChainABytes, address(pingPongChainB), chainB, expectedNonce, abi.encode(currentPingsA), firstMessageId);
    // vm.stopPrank();

    // // submit a malformed messageId, gets rejected
    // bytes32 secondMessageId = messageBusChainB.computeMessageId(chainA,pingPongChainABytes, address(pingPongChainB), 1, abi.encode(currentPingsA));
    // vm.expectRevert(bytes("Incorrect messageId submitted"));
    // messageBusChainB.executeMessage(chainA, pingPongChainABytes, address(pingPongChainB), 200000, 0, abi.encode(currentPingsA), secondMessageId);
    // vm.stopPrank();
}
