// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./ContextChainId.sol";
import "./MessageBusBase.sol";

contract MessageBusSender is MessageBusBase, ContextChainId {
    event MessageSent(
        address indexed sender,
        uint256 srcChainID,
        bytes32 receiver,
        uint256 indexed dstChainId,
        bytes message,
        uint256 nonce,
        bytes options,
        uint256 fee,
        bytes32 indexed messageId
    );

    /// @dev Nonce of the next sent message (amount of messages already sent)
    uint256 public nonce;
    /// @dev Collected messaging fees. Withdrawable by the owner.
    uint256 public fees;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function computeMessageId(
        address _srcAddress,
        uint256 _srcChainId,
        bytes32 _dstAddress,
        uint256 _dstChainId,
        uint256 _srcNonce,
        bytes calldata _message
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_srcAddress, _srcChainId, _dstAddress, _dstChainId, _srcNonce, _message));
    }

    function estimateFee(uint256 _dstChainId, bytes calldata _options) public view returns (uint256) {
        uint256 fee = executor.estimateGasFee(_dstChainId, _options);
        require(fee != 0, "Fee not set");
        return fee;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Rescues any gas in contract, aside from fees
     * @param to Address to which to rescue gas to
     */
    function rescueGas(address payable to) external onlyOwner {
        uint256 withdrawAmount = address(this).balance - fees;
        to.transfer(withdrawAmount);
    }

    /**
     * @notice Withdraws accumulated fees in native gas token, based on fees variable.
     * @param to Address to withdraw gas fees to, which can be specified in the event owner() can't receive native gas
     */
    function withdrawGasFees(address payable to) external onlyOwner {
        to.transfer(fees);
        delete fees;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           MESSAGING LOGIC                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Sends a message to a receiving contract address on another chain.
     * Sender must make sure that the message is unique and not a duplicate message.
     * Unspent gas fees would be transferred back to tx.origin.
     * @param _receiver The bytes32 address of the destination contract to be called
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _message The arbitrary payload to pass to the destination chain receiver
     * @param _options Versioned struct used to instruct message executor on how to proceed with gas limits
     */
    function sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options
    ) external payable {
        /**
         * @dev We're using `tx.origin` instead of `msg.sender` here, because
         * it's expected that the vast majority of interactions with {MessageBus}
         * will be done by the smart contracts. If they truly wanted to receive unspent
         * gas back, they should've specified themselves as a refund address.
         *
         * `tx.origin` is always an EOA that submitted the tx, and paid the gas fees,
         * so returning overspent fees to it by default makes sense. This address is
         * only going to be used for receiving unspent gas, so the usual
         * "do not use tx.origin" approach can not be applied here.
         *
         * Also, some of the contracts interacting with {MessageBus} might have no way
         * to receive gas, causing sendMessage to revert in case of overpayment, if
         * `msg.sender` was used by default.
         */
        // solhint-disable-next-line
        _sendMessage(_receiver, _dstChainId, _message, _options, payable(tx.origin));
    }

    /**
     * @notice Sends a message to a receiving contract address on another chain.
     * Sender must make sure that the message is unique and not a duplicate message.
     * Unspent gas fees will be refunded to specified address.
     * @param _receiver The bytes32 address of the destination contract to be called
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _message The arbitrary payload to pass to the destination chain receiver
     * @param _options Versioned struct used to instruct message executor on how to proceed with gas limits
     * @param _refundAddress Address that will receive unspent gas fees
     */
    function sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options,
        address payable _refundAddress
    ) external payable {
        _sendMessage(_receiver, _dstChainId, _message, _options, _refundAddress);
    }

    /// @dev Sending messages is disabled, when {MessageBus} is paused.
    function _sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options,
        address payable _refundAddress
    ) internal whenNotPaused {
        // Check that we're not sending to the local chain
        require(_dstChainId != localChainId, "Invalid chainId");
        // Check that messaging fee is fully covered
        uint256 fee = estimateFee(_dstChainId, _options);
        require(msg.value >= fee, "Insufficient gas fee");
        // Compute individual message identifier
        bytes32 msgId = computeMessageId(msg.sender, localChainId, _receiver, _dstChainId, nonce, _message);
        emit MessageSent(msg.sender, localChainId, _receiver, _dstChainId, _message, nonce, _options, fee, msgId);
        fees += fee;
        ++nonce;
        // refund gas fees in case of overpayment
        if (msg.value > fee) {
            _refundAddress.transfer(msg.value - fee);
        }
    }
}
