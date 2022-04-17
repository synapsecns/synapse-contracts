// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IMessageBus {
    
    /**
     * @notice Sends a message to a receiving contract address on another chain. 
     * Sender must make sure that the message is unique and not a duplicate message.
     * @param _receiver The bytes32 address of the destination contract to be called
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _message The arbitrary payload to pass to the destination chain receiver
     * @param _options Versioned struct used to instruct relayer on how to proceed with gas limits
     */
    function sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options
    ) external payable;

    /**
     * @notice Relayer executes messages through an authenticated method to the destination receiver
     based on the originating transaction on source chain
     * @param _srcChainId Originating chain ID - typically a standard EVM chain ID, but may refer to a Synapse-specific chain ID on nonEVM chains
     * @param _srcAddress Originating bytes address of the message sender on the srcChain
     * @param _dstAddress Destination address that the arbitrary message will be passed to
     * @param _gasLimit Gas limit to be passed alongside the message, depending on the fee paid on srcChain
     * @param _message Arbitrary message payload to pass to the destination chain receiver
     */
    function executeMessage(
        uint256 _srcChainId,
        bytes calldata _srcAddress,
        address _dstAddress,
        uint256 _gasLimit,
        uint256 _nonce,
        bytes calldata _message
    ) external;

    /**
     * @notice Withdraws message fee in the form of native gas token.
     * @param _account The address receiving the fee.
     */
    function withdrawFee(
        address _account
    ) external;

}
