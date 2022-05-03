// SPDX-License-Identifier: MIT

import "../framework/SynMessagingReceiver.sol";

pragma solidity 0.8.13;

/** @title Example app of sending multiple messages in one transaction
 */

contract BatchMessageSender is SynMessagingReceiver {
    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function sendMultipleMessages(bytes32[] memory _receiver, uint256[] memory _dstChainId, bytes[] memory _message, bytes[] memory _options) public payable {
        require(_receiver.length == _dstChainId.length);
        require(_receiver.length == _message.length);
        require(_receiver.length == _options.length);

        uint256 feePerMessage = msg.value / _message.length;

        // Care for block gas limit
        for (uint16 i = 0; i < _message.length; i++) {
            require(trustedRemoteLookup[_dstChainId[i]] != bytes32(0), "Receiver not trusted remote");
            IMessageBus(messageBus).sendMessage{value: feePerMessage}(_receiver[i], _dstChainId[i], _message[i], _options[i]);
        }
    }

    function _handleMessage(bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor) internal override returns (MsgExecutionStatus) {
            return MsgExecutionStatus.Success;
        }
}
