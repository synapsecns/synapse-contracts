pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../../contracts/messaging/EndpointReceiver.sol";
import "../../contracts/messaging/AuthVerifier.sol";

contract EndpointReceiverTest is Test {
    EndpointReceiver public endpointReceiver;
    AuthVerifier public authVerifier; 


    function setUp() public {
        authVerifier = new AuthVerifier(address(1337));
        endpointReceiver = new EndpointReceiver(address(authVerifier));
    }

    function addressToBytes32(address _addr) pure public returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function testComputeMessageId() public returns(bytes32) {
        uint256 srcChainId = 1; 
        bytes32 srcAddress = addressToBytes32(address(1338));
        address dstAddress = address(0x2796317b0fF8538F253012862c06787Adfb8cEb6);
        uint256 nonce = 0;
        bytes memory message = bytes("");

        bytes32 expectedMessageId = keccak256(abi.encode(
            srcChainId, srcAddress, block.chainid, dstAddress, nonce, message
        ));

        bytes32 messageId = endpointReceiver.computeMessageId(srcChainId, srcAddress, dstAddress, nonce, message);
        assertEq(messageId, expectedMessageId);
        return messageId;
    }

    // Authorized actor can update status of messages, and they are set correctly
    function testAuthorizedUpdateMessageStatus() public {
        bytes32 messageId = testComputeMessageId();
        EndpointReceiver.TxStatus initialStatus = endpointReceiver.getExecutedMessage(messageId);
        endpointReceiver.updateMessageStatus(messageId, EndpointReceiver.TxStatus.Success);
        EndpointReceiver.TxStatus finalStatus = endpointReceiver.getExecutedMessage(messageId);
        assertGt(uint(finalStatus), uint(initialStatus));
    }

    function testUnauthorizedUpdateMessageStatus() public {
        bytes32 messageId = testComputeMessageId();
        vm.prank(address(9999));
        vm.expectRevert("Ownable: caller is not the owner");
        endpointReceiver.updateMessageStatus(messageId, EndpointReceiver.TxStatus.Success);
    }

    function testUnauthorizedMessageSender() public {
        uint256 srcChainId = 1; 
        bytes32 srcAddress = addressToBytes32(address(1338));
        address dstAddress = address(0x2796317b0fF8538F253012862c06787Adfb8cEb6);
        uint256 nonce = 0;
        bytes memory message = bytes("");
        bytes32 messageId = testComputeMessageId();

        vm.prank(address(1337));
        // vm.expectRevert("Unauthenticated caller");
        endpointReceiver.executeMessage(srcChainId, srcAddress, dstAddress, 200000, nonce, message, messageId);

        // vm.expectCall(address(authVerifier), abi.encodeCall(authVerifier.msgAuth, (abi.encode(address(1337)))));

    }
}
