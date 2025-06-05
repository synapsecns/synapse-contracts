pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/MessageBusSender.sol";
import "../../contracts/messaging/GasFeePricing.sol";

import "./GasFeePricing.t.sol";

contract MessageBusSenderTest is Test {
    MessageBusSender public messageBusSender;
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
        messageBusSender = new MessageBusSender(address(gasFeePricing));
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
    function testUnsetEstimateFeeRevert() public {
        vm.expectRevert("Fee not set");
        messageBusSender.estimateFee(1, bytes(""));
    }

    function testSendMessageWrongChainIDRevert() public {
        bytes32 receiverAddress = addressToBytes32(address(1337));
        // 99 is default foundry chain id
        vm.expectRevert("Fee not set");
        messageBusSender.sendMessage(receiverAddress, 99, bytes(""), bytes(""));
    }

    // Enforce fees above returned fee amount from fee calculator
    function testSendMessageWithLowFeesRevert() public {
        uint256 dstChainId = gasFeePricingTest.expectedDstChainId();
        uint256 estimatedFee = messageBusSender.estimateFee(dstChainId, bytes(""));
        bytes32 receiverAddress = addressToBytes32(address(1337));
        vm.expectRevert("Insuffient gas fee");
        messageBusSender.sendMessage{value: estimatedFee - 1}(receiverAddress, dstChainId, bytes(""), bytes(""));
    }

    // Fee calculator reverts upon 0 fees (Fee is unset)
    function testMessageOnUnsetFeesRevert() public {
        uint256 dstChainId = gasFeePricingTest.expectedDstChainId() - 1;
        vm.expectRevert("Fee not set");
        uint256 estimatedFee = messageBusSender.estimateFee(dstChainId, bytes(""));
        bytes32 receiverAddress = addressToBytes32(address(1337));
        vm.expectRevert("Fee not set");
        messageBusSender.sendMessage{value: estimatedFee}(receiverAddress, dstChainId, bytes(""), bytes(""));
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
        console.logBytes(abi.encode(address(0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9)));
        console.logBytes32(addressToBytes32(address(0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9)));
        console.logBytes(abi.encodePacked(address(0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9)));
    }
}
