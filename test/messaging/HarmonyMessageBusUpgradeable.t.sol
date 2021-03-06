// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/HarmonyMessageBusUpgradeable.sol";
import "../../contracts/messaging/AuthVerifier.sol";
import "../../contracts/messaging/MessageBusUpgradeable.sol";
import "./GasFeePricing.t.sol";

import "../utils/Utilities.sol";

import "@openzeppelin/contracts-4.5.0/proxy/transparent/TransparentUpgradeableProxy.sol";

// this is a temporary test file against Harmony until https://github.com/harmony-one/harmony/issues/4129
// is merged. It runs tests we run on MessageBusUpgradeableTest and adds tests around custom chain ids.
contract HarmonyMessageBusUpgradeableTest is Test {
    HarmonyMessageBusUpgradeable public messageBus;
    AuthVerifier public authVerifier;

    GasFeePricing public gasFeePricing;
    GasFeePricingTest public gasFeePricingTest;

    Utilities utils;

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

    function setUp() public {
        utils = new Utilities();
        // setup gas fee pricing contracts
        gasFeePricing = new GasFeePricing();
        gasFeePricingTest = new GasFeePricingTest();
        gasFeePricing.setCostPerChain(
            gasFeePricingTest.expectedDstChainId(),
            gasFeePricingTest.expectedDstGasPrice(),
            gasFeePricingTest.expectedGasTokenPriceRatio()
        );

        authVerifier = new AuthVerifier(address(1337));
        HarmonyMessageBusUpgradeable impl = new HarmonyMessageBusUpgradeable();
        // Setup proxy with needed logic and custom admin,
        // we don't need to upgrade anything, so no need to setup ProxyAdmin
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(420), bytes(""));
        messageBus = HarmonyMessageBusUpgradeable(address(proxy));
        messageBus.initialize(address(gasFeePricing), address(authVerifier));
    }

    function testUnauthorizedPauseUnpause() public {
        // try pausing from unauthorized address
        vm.prank(address(999));
        vm.expectRevert("Ownable: caller is not the owner");
        messageBus.pause();

        // switch to authorized address, pause
        vm.prank(address(this));
        messageBus.pause();

        // try pausing from unauthorized address
        vm.prank(address(999));
        vm.expectRevert("Ownable: caller is not the owner");
        messageBus.unpause();

        // try unpausing from correct address
        vm.prank(address(this));
        messageBus.unpause();
    }

    function testPausedMessageReceive() public {
        // pause the contract
        vm.prank(address(this));
        messageBus.pause();

        uint256 srcChainId = 1;
        bytes32 srcAddress = addressToBytes32(address(1338));
        address dstAddress = address(0x2796317b0fF8538F253012862c06787Adfb8cEb6);
        uint256 nonce = 0;
        bytes memory message = bytes("");
        bytes32 messageId = keccak256("testMessageId");

        vm.prank(address(999));
        vm.expectRevert("Pausable: paused");

        messageBus.executeMessage(srcChainId, srcAddress, dstAddress, 200000, nonce, message, messageId);
    }

    function testPausedMessageSend() public {
        // pause the contract
        vm.prank(address(this));
        messageBus.pause();

        vm.expectRevert("Pausable: paused");
        bytes32 receiverAddress = addressToBytes32(address(1337));
        messageBus.sendMessage{value: 4}(receiverAddress, 121, bytes(""), bytes(""));
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // use block.chainID. Should be rejected
    function testSendMessagef() public {
        uint256 estimatedFee = messageBus.estimateFee(gasFeePricingTest.expectedDstChainId(), bytes(""));
        uint64 currentNonce = messageBus.nonce();
        bytes32 receiverAddress = addressToBytes32(address(1337));

        // TODO: Check data, so false should become true
        vm.expectEmit(true, true, false, true);
        emit MessageSent(
            address(this),
            1666600000,
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            currentNonce,
            bytes(""),
            estimatedFee,
            messageBus.computeMessageId(
                address(this),
                1666600000,
                receiverAddress,
                gasFeePricingTest.expectedDstChainId(),
                currentNonce,
                bytes("")
            )
        );
        messageBus.sendMessage{value: estimatedFee}(
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            bytes("")
        );
    }

    function testStorageUpgrade() public {
        uint256 estimatedFee = messageBus.estimateFee(gasFeePricingTest.expectedDstChainId(), bytes(""));
        bytes32 receiver = keccak256("receiver");
        uint256 count = 5;
        // send a few txs to have non-zero fees, nonce
        for (uint256 i = 0; i < count; ++i) {
            messageBus.sendMessage{value: estimatedFee}(
                receiver,
                gasFeePricingTest.expectedDstChainId(),
                bytes(""),
                bytes("")
            );
        }

        // "receive" a few txs to have some stored delivered messageIds
        for (uint256 i = 0; i < count; ++i) {
            bytes32 msgId = keccak256(abi.encode("test", i));
            hoax(address(1337));
            messageBus.executeMessage(1, receiver, address(this), 100000, i, bytes(""), msgId);
            require(uint8(messageBus.getExecutedMessage(msgId)) == 1, "msg not delivered");
        }
        // sanity check before upgrade
        _checkState(estimatedFee * count, count);

        MessageBusUpgradeable newImpl = new MessageBusUpgradeable();
        utils.upgradeTo(address(messageBus), address(newImpl));
        // check state post upgrade
        _checkState(estimatedFee * count, count);
    }

    function executeMessage(
        bytes32,
        uint256,
        bytes calldata,
        address
    ) external view {
        this;
    }

    function _checkState(uint256 fees, uint256 count) internal {
        // check MessageBusSender state
        assertEq(messageBus.gasFeePricing(), address(gasFeePricing), "GasFeePricing rekt");
        assertEq(messageBus.fees(), fees, "fees rekt");
        assertEq(messageBus.nonce(), count, "nonce rekt");
        // check MessageBusReceiver state
        assertEq(messageBus.authVerifier(), address(authVerifier), "authVerifier rekt");
        for (uint256 i = 0; i < count; ++i) {
            bytes32 msgId = keccak256(abi.encode("test", i));
            assertEq(uint8(messageBus.getExecutedMessage(msgId)), 1, "executedMessages rekt");
        }
        // check Ownable state
        assertEq(messageBus.owner(), address(this), "owner rekt");
        // check Pausable state
        assertFalse(messageBus.paused(), "paused rekt");
    }
}
