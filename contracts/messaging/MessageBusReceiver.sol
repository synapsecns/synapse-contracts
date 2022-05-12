// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "@openzeppelin/contracts-4.5.0/security/Pausable.sol";
import "./interfaces/IAuthVerifier.sol";
import "./interfaces/ISynMessagingReceiver.sol";

contract MessageBusReceiver is Ownable, Pausable {
    address public authVerifier;

    enum TxStatus {
        Null,
        Success,
        Fail
    }

    // Store all successfully executed messages
    mapping(bytes32 => TxStatus) executedMessages;

    // TODO: Rename to follow one standard convention -> Send -> Receive?
    event Executed(
        bytes32 indexed messageId,
        TxStatus status,
        address indexed _dstAddress,
        uint64 srcChainId,
        uint64 srcNonce
    );
    event CallReverted(string reason);

    constructor(address _authVerifier) {
        authVerifier = _authVerifier;
    }

    function getExecutedMessage(bytes32 _messageId)
        external
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
    ) external whenNotPaused {
        // In order to guarentee that an individual message is only executed once, a messageId is passed
        // enforce that this message ID hasn't already been tried ever
        bytes32 messageId = _messageId;
        require(
            executedMessages[messageId] == TxStatus.Null,
            "Message already executed"
        );
        // Authenticate executeMessage, will revert if not authenticated
        IAuthVerifier(authVerifier).msgAuth(abi.encode(msg.sender));
        // Message is now in-flight, adjust status
        // executedMessages[messageId] = TxStatus.Pending;

        TxStatus status;
        try
            ISynMessagingReceiver(_dstAddress).executeMessage{gas: _gasLimit}(
                _srcAddress,
                _srcChainId,
                _message,
                msg.sender
            )
        {
            // Assuming success state if no revert
            status = TxStatus.Success;
        } catch (bytes memory reason) {
            // call hard reverted & failed
            emit CallReverted(getRevertMsg(reason));
            status = TxStatus.Fail;
        }

        executedMessages[messageId] = status;
        emit Executed(
            messageId,
            status,
            _dstAddress,
            uint64(_srcChainId),
            uint64(_nonce)
        );
    }

    /** HELPER VIEW FUNCTION */
    // https://ethereum.stackexchange.com/a/83577
    // https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/base/Multicall.sol
    function getRevertMsg(bytes memory _returnData)
        private
        pure
        returns (string memory)
    {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /** CONTRACT CONFIG */

    function updateMessageStatus(bytes32 _messageId, TxStatus _status)
        public
        onlyOwner
    {
        executedMessages[_messageId] = _status;
    }

    function updateAuthVerifier(address _authVerifier) public onlyOwner {
        require(_authVerifier != address(0), "Cannot set to 0");
        authVerifier = _authVerifier;
    }

    // PAUSABLE FUNCTIONS ***/
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
