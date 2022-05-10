// SPDX-License-Identifier: MIT

import "../framework/SynMessagingReceiver.sol";

pragma solidity 0.8.13;

/** @title Example app of sending multiple messages in one transaction
 */

contract BatchMessageSender is SynMessagingReceiver {
    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    function sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options
    ) external payable {
        // use tx.origin for gas refund by default, so that older contracts,
        // interacting with MessageBus that don't have a fallback/receive
        // (i.e. not able to receive gas), will continue to work
        _sendMultipleMessages(
            _receiver,
            _dstChainId,
            _message,
            _options,
            payable(tx.origin)
        );
    }

    function sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options,
        address payable _refundAddress
    ) external payable {
        _sendMultipleMessages(
            _receiver,
            _dstChainId,
            _message,
            _options,
            _refundAddress
        );
    }

    function _sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options,
        address payable _refundAddress
    ) internal {
        require(
            _receiver.length == _dstChainId.length,
            "dstChainId bad length"
        );
        require(_receiver.length == _message.length, "message bad length");
        require(_receiver.length == _options.length, "options bad length");

        uint256 feePerMessage = msg.value / _message.length;

        // Care for block gas limit
        for (uint16 i = 0; i < _message.length; i++) {
            require(
                trustedRemoteLookup[_dstChainId[i]] != bytes32(0),
                "Receiver not trusted remote"
            );
            IMessageBus(messageBus).sendMessage{value: feePerMessage}(
                _receiver[i],
                _dstChainId[i],
                _message[i],
                _options[i],
                _refundAddress
            );
        }
    }

    function _handleMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor
    ) internal override {
        return;
    }
}
