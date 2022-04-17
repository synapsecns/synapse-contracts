pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import "../../contracts/messaging/MessageBus.sol";
import "../../contracts/messaging/GasFeePricing.sol";
import "../../contracts/messaging/AuthVerifier.sol";
import "../../contracts/messaging/apps/PingPong.sol";


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
        address payable node = users[0];
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


    function testPing() public {
        vm.travel(1000);
        pingPongChainA.ping(2000, address(pingPongChainB), 0);
    }
}