// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./MessageBusBase.sol";

contract MessageBusReceiver is MessageBusBase {
    enum TxStatus {
        Null,
        Success,
        Fail
    }

    event Executed(
        bytes32 indexed messageId,
        TxStatus status,
        address indexed dstAddress,
        uint256 indexed srcChainId,
        uint256 srcNonce
    );

    event CallReverted(string reason);

    /// @dev Status of all executed messages
    mapping(bytes32 => TxStatus) public executedMessages;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           MESSAGING LOGIC                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Relayer executes messages through an authenticated method to the destination receiver
     * based on the originating transaction on source chain
     * @param _srcChainId Originating chain ID - typically a standard EVM chain ID,
     * but may refer to a Synapse-specific chain ID on nonEVM chains
     * @param _srcAddress Originating bytes32 address of the message sender on the srcChain
     * @param _dstAddress Destination address that the arbitrary message will be passed to
     * @param _message Arbitrary message payload to pass to the destination chain receiver
     * @param _srcNonce Nonce of the message on the originating chain
     * @param _options Versioned struct used to instruct message executor on how to proceed with gas limits,
     * gas airdrop, etc
     * @param _messageId Unique message identifier, computed when sending message on originating chain
     * @param _proof Byte string containing proof that message was sent from originating chain
     */
    function executeMessage(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        bytes calldata _message,
        uint256 _srcNonce,
        bytes calldata _options,
        bytes32 _messageId,
        bytes calldata _proof
    ) external whenNotPaused {
        /// @dev Executing messages is disabled, when {MessageBus} is paused.

        // In order to guarantee that an individual message is only executed once, a messageId is passed
        // enforce that this message ID hasn't already been tried ever
        require(executedMessages[_messageId] == TxStatus.Null, "Message already executed");
        // Authenticate executeMessage, will revert if not authenticated
        verifier.msgAuth(abi.encode(msg.sender, _messageId, _proof));

        TxStatus status;
        try executor.executeMessage(_srcChainId, _srcAddress, _dstAddress, _message, _options) {
            // Assuming success state if no revert
            status = TxStatus.Success;
        } catch (bytes memory reason) {
            // call hard reverted & failed
            emit CallReverted(_getRevertMsg(reason));
            status = TxStatus.Fail;
        }

        executedMessages[_messageId] = status;
        emit Executed(_messageId, status, _dstAddress, _srcChainId, _srcNonce);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    // https://ethereum.stackexchange.com/a/83577
    // https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/base/Multicall.sol
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";
        // solhint-disable-next-line
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
