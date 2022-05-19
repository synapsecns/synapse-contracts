// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable-4.5.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/security/PausableUpgradeable.sol";

import "./interfaces/IAuthVerifier.sol";
import "./interfaces/ISynMessagingReceiver.sol";

contract MessageBusReceiverUpgradeable is
    OwnableUpgradeable,
    PausableUpgradeable
{
    enum TxStatus {
        Null,
        Success,
        Fail
    }

    // TODO: Rename to follow one standard convention -> Send -> Receive?
    event Executed(
        bytes32 indexed messageId,
        TxStatus status,
        address indexed _dstAddress,
        uint64 srcChainId,
        uint64 srcNonce
    );
    event CallReverted(string reason);

    address public authVerifier;

    // Store all successfully executed messages
    mapping(bytes32 => TxStatus) internal executedMessages;

    function __MessageBusReceiver_init(address _authVerifier) internal {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __MessageBusReceiver_init_unchained(_authVerifier);
    }

    function __MessageBusReceiver_init_unchained(address _authVerifier)
        internal
    {
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
        // In order to guarantee that an individual message is only executed once, a messageId is passed
        // enforce that this message ID hasn't already been tried ever
        require(
            executedMessages[_messageId] == TxStatus.Null,
            "Message already executed"
        );
        // Authenticate executeMessage, will revert if not authenticated
        IAuthVerifier(authVerifier).msgAuth(abi.encode(msg.sender));

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
            emit CallReverted(_getRevertMsg(reason));
            status = TxStatus.Fail;
        }

        executedMessages[_messageId] = status;
        emit Executed(
            _messageId,
            status,
            _dstAddress,
            uint64(_srcChainId),
            uint64(_nonce)
        );
    }

    /** HELPER VIEW FUNCTION */
    // https://ethereum.stackexchange.com/a/83577
    // https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/base/Multicall.sol
    function _getRevertMsg(bytes memory _returnData)
        internal
        pure
        returns (string memory)
    {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";
        // solhint-disable-next-line
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    /** CONTRACT CONFIG */

    function updateMessageStatus(bytes32 _messageId, TxStatus _status)
        external
        onlyOwner
    {
        executedMessages[_messageId] = _status;
    }

    function updateAuthVerifier(address _authVerifier) external onlyOwner {
        require(_authVerifier != address(0), "Cannot set to 0");
        authVerifier = _authVerifier;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
