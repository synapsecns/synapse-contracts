pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../utils/Utilities.sol";

import "../../contracts/messaging/dfk/bridge/TearBridge.sol";
import "../../contracts/messaging/dfk/inventory/GaiaTears.sol";

import "../../contracts/messaging/MessageBus.sol";
import "../../contracts/messaging/GasFeePricing.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract TearBridgeTest is Test {
    Utilities internal utils;
    address payable[] internal users;
    MessageBus public messageBus;
    GasFeePricing public gasFeePricing;
    AuthVerifier public authVerifier;
    TearBridge public tearBridge;
    GaiaTears public gaiaTears;

    address payable public node;

    struct MessageFormat {
        address dstUser;
        uint256 dstTearAmount;
    }

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

    event GaiaSent(address indexed dstUser, uint256 arrivalChainId);
    event GaiaArrived(address indexed dstUser, uint256 arrivalChainId);

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function setUp() public {
        gasFeePricing = new GasFeePricing();

        utils = new Utilities();
        users = utils.createUsers(10);
        node = users[0];
        vm.label(node, "Node");

        authVerifier = new AuthVerifier(node);
        messageBus = new MessageBus(
            address(gasFeePricing),
            address(authVerifier)
        );
        gaiaTears = new GaiaTears();

        tearBridge = new TearBridge(address(messageBus), address(gaiaTears));
        tearBridge.setMsgGasLimit(800000);
        gaiaTears.grantRole(keccak256("MINTER_ROLE"), address(tearBridge));
        gasFeePricing.setCostPerChain(
            1666700000,
            2000000000,
            100000000000000000
        );
        gasFeePricing.setCostPerChain(335, 2000000000, 100000000000000000);
        tearBridge.setTrustedRemote(1666700000, bytes32("trustedRemoteB"));
        tearBridge.setTrustedRemote(335, bytes32("trustedRemoteA"));
    }

    function testGaiaSendMessage() public {
        gaiaTears.grantRole(keccak256("MINTER_ROLE"), address(this));
        gaiaTears.mint(users[1], 1000);
        gaiaTears.revokeRole(keccak256("MINTER_ROLE"), address(this));
        vm.startPrank(users[1]);
        assertEq(gaiaTears.balanceOf(users[1]), 1000);
        gaiaTears.approve(address(tearBridge), 1000);
        // check first two topics, but don't check data or msgId
        vm.expectEmit(true, true, false, false);
        emit MessageSent(
            address(tearBridge),
            block.chainid,
            bytes32("1337"),
            335, // chain id
            "0x", // example possible message
            messageBus.nonce(),
            "0x", // null
            100000000000000000,
            keccak256("placeholder_message_id")
        );
        tearBridge.sendTear{value: 1000000000000000000}(1000, 335);
        // GAIA burnt, and message sent to mint equiv. gaia to DFK Chain
        assertEq(gaiaTears.balanceOf(users[1]), 0);
    }

    function testGaiaExecuteMessage() public {
        MessageFormat memory msgFormat = MessageFormat({
            dstUser: users[1],
            dstTearAmount: 1000
        });

        bytes memory message = abi.encode(msgFormat);
        assertEq(gaiaTears.balanceOf(users[1]), 0);
        vm.prank(address(messageBus));
        tearBridge.executeMessage(
            bytes32("trustedRemoteB"),
            1666700000,
            message,
            msg.sender
        );
        assertEq(gaiaTears.balanceOf(users[1]), 1000);
    }
}
