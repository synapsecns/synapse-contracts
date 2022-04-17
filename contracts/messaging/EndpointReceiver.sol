// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "./interfaces/IAuthVerifier.sol";
import "./interfaces/IMessageReceiverApp.sol";

contract EndpointReceiver is Ownable {
    enum TxStatus {
        Null,
        Success,
        Fail,
        Fallback,
        Pending
    }

    // Store all successfully executed messages
    mapping(bytes32 => TxStatus) public executedMessages;

    function computeMessageId(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        uint256 _nonce,
        bytes calldata _message
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _srcChainId,
                    _srcAddress,
                    block.chainid,
                    _dstAddress,
                    _nonce,
                    _message
                )
            );
    }

    function getExecutedMessage(bytes32 _messageId)
        public
        view
        returns (TxStatus)
    {
        return executedMessages[_messageId];
    }

    /**
     * @notice Relayer executes messages through an authenticated method to the destination receiver
     based on the originating transaction on source chain
     * @param _srcChainId Originating chain ID - typically a standard EVM chain ID, but may refer to a Synapse-specific chain ID on nonEVM chains
     * @param _srcAddress Originating bytes32 address of the message sender on the srcChain
     * @param _dstAddress Destination address that the arbitrary message will be passed to
     * @param _gasLimit Gas limit to be passed alongside the message, depending on the fee paid on srcChain
     * @param _message Arbitrary message payload to pass to the destination chain receiver
     */
    function executeMessage(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        uint256 _gasLimit,
        uint256 _nonce,
        bytes calldata _message,
        bytes32 _messageId
    ) external payable {
        // In order to guarentee that an individual message is only executed once, a messageId is generated.
        bytes32 messageId = computeMessageId(
            _srcChainId,
            _srcAddress,
            _dstAddress,
            _nonce,
            _message
        );
        require(messageId == _messageId, "Incorrect messageId submitted");
        // enforce that this message ID hasn't already been tried ever
        require(
            executedMessages[messageId] == TxStatus.Null,
            "Message already executed"
        );
        // Message is now in-flight, adjust status
        executedMessages[messageId] = TxStatus.Pending;

        // Authenticate executeMessage
        // call auth library here

        // (bool ok, bytes memory res) = _dstAddress.call{gas: _gasLimit, value: msg.value}(
        //     abi.encodeWithSelector(
        //         IMessageReceiverApp.executeMessage.selector,
        //         _srcAddress,
        //         _srcChainId,
        //         _message,
        //         msg.sender
        //     )
        // );
        
        // if (ok) {
        //     return abi.decode((res), (IMessageReceiverApp.ExecutionStatus));
        // } else {
        //     handleExecutionRevert(gasLeftBeforeExecution, res);
        //     return IMessageReceiverApp.ExecutionStatus.Fail;
        // }
    }
}
