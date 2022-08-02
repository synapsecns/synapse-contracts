// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "src-messaging/MessageBusUpgradeable.sol";
import "src-messaging/GasFeePricing.sol";

import "./GasFeePricing.t.sol";

import "@openzeppelin/contracts-4.5.0/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MessageBusSenderUpgradeableTest is Test {
    MessageBusUpgradeable public messageBusSender;
    GasFeePricing public gasFeePricing;
    GasFeePricingTest public gasFeePricingTest;

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

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function setUp() public {
        gasFeePricing = new GasFeePricing();
        gasFeePricingTest = new GasFeePricingTest();
        gasFeePricing.setCostPerChain(
            gasFeePricingTest.expectedDstChainId(),
            gasFeePricingTest.expectedDstGasPrice(),
            gasFeePricingTest.expectedGasTokenPriceRatio()
        );
        MessageBusUpgradeable impl = new MessageBusUpgradeable();
        // Setup proxy with needed logic and custom admin,
        // we don't need to upgrade anything, so no need to setup ProxyAdmin
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), address(420), bytes(""));
        messageBusSender = MessageBusUpgradeable(address(proxy));
        messageBusSender.initialize(address(gasFeePricing), address(0));
    }

    // Constructor initialized properly
    function testSetPricingAddress() public {
        assertEq(messageBusSender.gasFeePricing(), address(gasFeePricing));
    }

    // Test fee query on a set dstChain
    function testEstimateFee() public {
        uint256 estimatedFee = messageBusSender.estimateFee(gasFeePricingTest.expectedDstChainId(), bytes(""));
        assertEq(estimatedFee, gasFeePricingTest.expectedFeeDst43114());
    }

    // Test fee query on an unset dstChain
    function testFailUnsetEstimateFee() public {
        messageBusSender.estimateFee(1, bytes(""));
    }

    function testFailSendMessageWrongChainID() public {
        bytes32 receiverAddress = addressToBytes32(address(1337));
        // 99 is default foundry chain id
        messageBusSender.sendMessage(receiverAddress, 99, bytes(""), bytes(""));
    }

    // Enforce fees above returned fee amount from fee calculator
    function testFailSendMessageWithLowFees() public {
        uint256 estimatedFee = messageBusSender.estimateFee(gasFeePricingTest.expectedDstChainId(), bytes(""));
        bytes32 receiverAddress = addressToBytes32(address(1337));
        messageBusSender.sendMessage{value: estimatedFee - 1}(
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            bytes("")
        );
    }

    // Fee calculator reverts upon 0 fees (Fee is unset)
    function testFailMessageOnUnsetFees() public {
        uint256 estimatedFee = messageBusSender.estimateFee(gasFeePricingTest.expectedDstChainId() - 1, bytes(""));
        bytes32 receiverAddress = addressToBytes32(address(1337));
        messageBusSender.sendMessage{value: estimatedFee}(
            receiverAddress,
            gasFeePricingTest.expectedDstChainId() - 1,
            bytes(""),
            bytes("")
        );
    }

    // Send message without reversion, pay correct amount of fees, emit correct event
    function testSendMessage() public {
        uint256 estimatedFee = messageBusSender.estimateFee(gasFeePricingTest.expectedDstChainId(), bytes(""));
        uint64 currentNonce = messageBusSender.nonce();
        bytes32 receiverAddress = addressToBytes32(address(1337));
        // TODO: Check data, so false should become true
        vm.expectEmit(true, true, false, false);
        emit MessageSent(
            address(this),
            99,
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            currentNonce,
            bytes(""),
            estimatedFee,
            keccak256("placeholder_message_id")
        );
        messageBusSender.sendMessage{value: estimatedFee}(
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            bytes("")
        );
    }

    // Send message without reversion, pay correct amount of fees, emit correct event
    function testWithdrawFees() public {
        uint256 estimatedFee = messageBusSender.estimateFee(gasFeePricingTest.expectedDstChainId(), bytes(""));
        uint64 currentNonce = messageBusSender.nonce();
        bytes32 receiverAddress = addressToBytes32(address(1337));
        // TODO: Check data, so false should become true
        vm.expectEmit(true, true, false, false);
        emit MessageSent(
            address(this),
            99,
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            currentNonce,
            bytes(""),
            estimatedFee,
            keccak256("placeholder_message_id")
        );
        messageBusSender.sendMessage{value: estimatedFee}(
            receiverAddress,
            gasFeePricingTest.expectedDstChainId(),
            bytes(""),
            bytes("")
        );
        messageBusSender.withdrawGasFees(payable(address(1000)));
        assertEq(address(1000).balance, estimatedFee);
    }

    function testAddressABIEncode() public {
        address _address = 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9;
        emit log_named_bytes("  abi.encode", abi.encode(_address));
        emit log_named_bytes32("     bytes32", addressToBytes32(_address));
        emit log_named_bytes("encodePacked", abi.encodePacked(_address));
        emit log_named_address("     address", _address);
    }
}
