// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "./interfaces/IAuthVerifier.sol";
import "./interfaces/IMessageReceiverApp.sol";

import "forge-std/Test.sol";

contract EndpointReceiver is Ownable {
    address public authVerifier;

    enum TxStatus {
        Null,
        Success,
        Fail,
        Fallback,
        Pending
    }

    // Store all successfully executed messages
    mapping(bytes32 => TxStatus) public executedMessages;

    event Executed(
        bytes32 msgId,
        TxStatus status,
        address indexed _dstAddress,
        uint64 srcChainId,
        uint64 srcNonce
    );
    event NeedRetry(bytes32 indexed msgId, uint64 srcChainId, uint64 srcNonce);
    event CallReverted(string reason);

    constructor(address _authVerifier) {
        authVerifier = _authVerifier;
    }

    function computeMessageId(
        uint256 _srcChainId,
        bytes32 _srcAddress,
        address _dstAddress,
        uint256 _nonce,
        bytes calldata _message
    ) public view returns (bytes32) {
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
    ) external {
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
        // Authenticate executeMessage, will revert if not authenticated
        IAuthVerifier(authVerifier).msgAuth(abi.encode(msg.sender));
        // Message is now in-flight, adjust status
        // executedMessages[messageId] = TxStatus.Pending;

        TxStatus status;
        console.log("Getting to here");
        // try
        //     IMessageReceiverApp(_dstAddress).executeMessage{gas: _gasLimit}(_srcAddress, _srcChainId, _message, msg.sender) returns (IMessageReceiverApp.MsgExecutionStatus execStatus) {
        //     if (execStatus == IMessageReceiverApp.MsgExecutionStatus.Success) {
        //         status = TxStatus.Success;
        //     // TODO This state is not fully managed yet
        //     } else if (execStatus == IMessageReceiverApp.MsgExecutionStatus.Retry) {
        //          // handle permissionless retries or delete and only allow Success / Revert
        //         executedMessages[messageId] = TxStatus.Null;
        //         emit NeedRetry(messageId, uint64(_srcChainId), uint64(_nonce));
        //     }
        // } catch (
        //     bytes memory reason
        // ) {
        //     // call hard reverted & failed
        //     emit CallReverted(getRevertMsg(reason));
        //     status = TxStatus.Fail;
        // }

        (bool ok, bytes memory reason) = address(_dstAddress).call{
            gas: _gasLimit
        }(
            abi.encodeWithSelector(
                IMessageReceiverApp.executeMessage.selector,
                _srcAddress,
                _srcChainId,
                _message,
                msg.sender
            )
        );
        if (ok) {
            console.log(reason.length);
            IMessageReceiverApp.MsgExecutionStatus execStatus = abi.decode(
                (reason),
                (IMessageReceiverApp.MsgExecutionStatus)
            );
                if (execStatus == IMessageReceiverApp.MsgExecutionStatus.Success) {
                    status = TxStatus.Success;
                // TODO This state is not fully managed yet
                } else if (execStatus == IMessageReceiverApp.MsgExecutionStatus.Retry) {
                     // handle permissionless retries or delete and only allow Success / Revert
                    executedMessages[messageId] = TxStatus.Null;
                    emit NeedRetry(messageId, uint64(_srcChainId), uint64(_nonce));
                }
        } else {
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
}
