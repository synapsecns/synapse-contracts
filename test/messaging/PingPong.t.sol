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
    MessageBus public messageBusChainA;
    PingPong public pingPongChainA;
    GasFeePricing public gasFeePricingChainA;
    AuthVerifier public authVerifierChainA; 

    // Chain B 2000
    MessageBus public messageBusChainB;
    PingPong public pingPongChainB;
    GasFeePricing public gasFeePricingChainB;
    AuthVerifier public authVerifierChainB;

    address payable public node;
    event MessageSent(
        address indexed sender,
        uint256 srcChainID,
        bytes32 receiver,
        uint256 indexed dstChainId,
        bytes messages,
        bytes options,
        uint256 fee
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
        messageBusChainA = new MessageBus(address(gasFeePricingChainA), address(authVerifierChainA));
        messageBusChainB = new MessageBus(address(gasFeePricingChainB), address(authVerifierChainB));
        pingPongChainA = new PingPong(address(messageBusChainA));
        pingPongChainB = new PingPong(address(messageBusChainB));
        vm.deal(address(pingPongChainA), 100 ether);
        vm.deal(address(pingPongChainB), 100 ether);
        gasFeePricingChainA.setCostPerChain(2000, 30000000000, 25180000000000000);
        gasFeePricingChainB.setCostPerChain(1000, 30000000000, 25180000000000000);
    }


    function testPingPongE2E() public {
        // Chain A - 1000 chain ID. Call ping, message gets sent, processed, and event gets emitted. 
        vm.travel(1000);
        uint256 currentPings = pingPongChainA.numPings();
        uint256 expectedFee = messageBusChainA.estimateFee(2000, bytes(""));
        vm.expectEmit(true, true, false, false);
        emit MessageSent(
            address(pingPongChainA),
            block.chainid,
            utils.addressToBytes32(address(pingPongChainB)),
            2000,
            abi.encode(currentPings),
            bytes(""), // will have to be edited if contract changes
            expectedFee
        );
        pingPongChainA.ping(2000, address(pingPongChainB), currentPings);
        // TODO: Check that fee was transferred & enforced on MsgBus
        // Ping hit, move to next chain
        vm.travel(2000);
        // Relay tx construction
        bytes32 firstMessageId = messageBusChainB.computeMessageId(1000,utils.addressToBytes32(address(pingPongChainA)), address(pingPongChainB), 0, abi.encode(currentPings));
        vm.startPrank(address(node));
        messageBusChainB.executeMessage(1000, utils.addressToBytes32(address(pingPongChainA)), address(pingPongChainB), 200000, 0, abi.encode(currentPings), firstMessageId);
        // console.log(pingPongChainB.numPings());
        messageBusChainB.executeMessage(1000, utils.addressToBytes32(address(pingPongChainA)), address(pingPongChainB), 200000, 0, abi.encode(currentPings), firstMessageId);
        vm.stopPrank();
    }  
}