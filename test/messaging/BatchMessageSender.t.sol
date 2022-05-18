pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";
import "../../contracts/messaging/MessageBus.sol";
import "../../contracts/messaging/GasFeePricing.sol";
import "../../contracts/messaging/AuthVerifier.sol";
import "../../contracts/messaging/apps/BatchMessageSender.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract BatchMessageSenderTest is Test {
    Utilities internal utils;
    address payable[] internal users;

    MessageBus public messageBusChainA;
    GasFeePricing public gasFeePricingChainA;
    AuthVerifier public authVerifierChainA;
    BatchMessageSender public batchMessageSenderChainA;

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
        utils = new Utilities();
        users = utils.createUsers(10);
        node = users[0];
        vm.label(node, "Node");
        authVerifierChainA = new AuthVerifier(node);
        messageBusChainA = new MessageBus(
            address(gasFeePricingChainA),
            address(authVerifierChainA)
        );
        batchMessageSenderChainA = new BatchMessageSender(
            address(messageBusChainA)
        );
        vm.label(address(batchMessageSenderChainA), "BatchMessageSenderChainA");
        gasFeePricingChainA.setCostPerChain(
            43113,
            30000000000,
            25180000000000000
        );
        batchMessageSenderChainA.setTrustedRemote(
            43113,
            keccak256("Receiver!")
        );
    }

    function testSendMultipleMessages() public {
        bytes32[] memory receivers = new bytes32[](6);
        uint256[] memory dstChainIds = new uint256[](6);
        bytes[] memory messages = new bytes[](6);
        bytes[] memory options = new bytes[](6);

        for (uint256 i = 0; i < 6; i++) {
            receivers[i] = keccak256("Receiver!");
            dstChainIds[i] = 43113; // always to fuji
            messages[i] = abi.encode(true);
            options[i] = bytes("");
        }

        // this msg.value (fee) is entirely fake and way too high
        batchMessageSenderChainA.sendMultipleMessages{value: 10 ether}(
            receivers,
            dstChainIds,
            messages,
            options
        );
    }
}
