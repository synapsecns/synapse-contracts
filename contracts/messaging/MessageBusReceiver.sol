// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "@openzeppelin/contracts-4.5.0/security/Pausable.sol";

import "./interfaces/IAuthVerifier.sol";
import "./interfaces/IMessageExecutor.sol";

contract MessageBusReceiver is Ownable, Pausable {
    enum TxStatus {
        Null,
        Success,
        Fail
    }

    event Executed(
        bytes32 indexed messageId,
        TxStatus status,
        address indexed dstAddress,
        uint64 indexed srcChainId,
        uint64 srcNonce
    );

    event CallReverted(string reason);

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Contract used for authenticating validator address
    IAuthVerifier public verifier;
    /// @dev Contract used for executing received messages
    IMessageExecutor public executor;
    /// @dev Status of all executed messages
    mapping(bytes32 => TxStatus) public executedMessages;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              ONLY OWNER                              ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function updateAuthVerifier(IAuthVerifier _verifier) external onlyOwner {
        require(address(_verifier) != address(0), "Cannot set to 0");
        verifier = _verifier;
    }

    function updateMessageExecutor(IMessageExecutor _executor) external onlyOwner {
        require(address(_executor) != address(0), "Cannot set to 0");
        executor = _executor;
    }

    // TODO: how useful is that, if contract is immutable?
    function updateMessageStatus(bytes32 _messageId, TxStatus _status) external onlyOwner {
        executedMessages[_messageId] = _status;
    }

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
        /// @dev Sending messages is disabled, when {MessageBus} is paused.
        // In order to guarantee that an individual message is only executed once, a messageId is passed
        // enforce that this message ID hasn't already been tried ever
        require(executedMessages[_messageId] == TxStatus.Null, "Message already executed");
        // Authenticate executeMessage, will revert if not authenticated
        IAuthVerifier(verifier).msgAuth(abi.encode(msg.sender, _messageId, _proof));

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
        emit Executed(_messageId, status, _dstAddress, uint64(_srcChainId), uint64(_srcNonce));
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
