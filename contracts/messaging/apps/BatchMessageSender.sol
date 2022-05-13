// SPDX-License-Identifier: MIT

import "../framework/SynMessagingReceiver.sol";

pragma solidity 0.8.13;

/** @title Example app of sending multiple messages in one transaction
 */

contract BatchMessageSender is SynMessagingReceiver {
    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    /**
     * @notice Send multiple messages.
     * msg.value will be split evenly between these messages to cover their gas costs.
     * The unspent gas will be transferred back to tx.origin.
     */
    function sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options
    ) external payable {
        require(_message.length > 0, "No messages found");
        uint256[] memory fees = _splitFeeBetweenMessages(_message.length);
        // use tx.origin for gas refund by default, so that older contracts,
        // interacting with MessageBus that don't have a fallback/receive
        // (i.e. not able to receive gas), will continue to work
        _sendMultipleMessages(
            _receiver,
            _dstChainId,
            _message,
            _options,
            fees,
            payable(tx.origin)
        );
    }

    /**
     * @notice Send multiple messages, specifying amount of fees for every message.
     * The unspent gas will be transferred back to tx.origin.
     */
    function sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options,
        uint256[] memory _fees
    ) external payable {
        require(_message.length > 0, "No messages found");
        // use tx.origin for gas refund by default, so that older contracts,
        // interacting with MessageBus that don't have a fallback/receive
        // (i.e. not able to receive gas), will continue to work
        _sendMultipleMessages(
            _receiver,
            _dstChainId,
            _message,
            _options,
            _fees,
            payable(tx.origin)
        );
    }

    /**
     * @notice Send multiple messages.
     * msg.value will be split evenly between these messages to cover their gas costs.
     * The unspent gas will be transferred back to specified refund address.
     */
    function sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options,
        address payable _refundAddress
    ) external payable {
        require(_message.length > 0, "No messages found");
        uint256[] memory fees = _splitFeeBetweenMessages(_message.length);
        _sendMultipleMessages(
            _receiver,
            _dstChainId,
            _message,
            _options,
            fees,
            _refundAddress
        );
    }

    /**
     * @notice Send multiple messages, specifying amount of fees for every message.
     * The unspent gas will be transferred back to specified refund address.
     */
    function sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options,
        uint256[] memory _fees,
        address payable _refundAddress
    ) external payable {
        require(_message.length > 0, "No messages found");
        _sendMultipleMessages(
            _receiver,
            _dstChainId,
            _message,
            _options,
            _fees,
            _refundAddress
        );
    }

    function _splitFeeBetweenMessages(uint256 _amount)
        internal
        returns (uint256[] memory fees)
    {
        uint256 feePerMessage = msg.value / _amount;
        fees = new uint256[](_amount);
        // Use avg fee for the first N-1 messages
        for (uint256 i = 0; i < _amount - 1; ++i) {
            fees[i] = feePerMessage;
        }
        // Use the remainder for the last message
        fees[_amount - 1] = msg.value - feePerMessage * (_amount - 1);
    }

    function _sendMultipleMessages(
        bytes32[] memory _receiver,
        uint256[] memory _dstChainId,
        bytes[] memory _message,
        bytes[] memory _options,
        uint256[] memory _fees,
        address payable _refundAddress
    ) internal {
        require(
            _receiver.length == _dstChainId.length,
            "dstChainId bad length"
        );
        require(_receiver.length == _message.length, "message bad length");
        require(_receiver.length == _options.length, "options bad length");
        require(_receiver.length == _fees.length, "fees bad length");

        uint256 totalFee = 0;
        for (uint256 i = 0; i < _message.length; i++) {
            totalFee += _fees[i];
        }
        require(totalFee <= msg.value, "msg.value doesn't cover fees");

        // Care for block gas limit
        for (uint16 i = 0; i < _message.length; i++) {
            require(
                trustedRemoteLookup[_dstChainId[i]] != bytes32(0),
                "Receiver not trusted remote"
            );
            IMessageBus(messageBus).sendMessage{value: _fees[i]}(
                _receiver[i],
                _dstChainId[i],
                _message[i],
                _options[i],
                _refundAddress
            );
        }
        // refund gas fees in case of overpayment
        if (msg.value > totalFee) {
            _refundAddress.transfer(msg.value - totalFee);
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
