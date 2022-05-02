// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../interfaces/ISynMessagingReceiver.sol";
import "../interfaces/IMessageBus.sol";
import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

abstract contract SynMessagingReceiver is ISynMessagingReceiver, Ownable {
    
    address public messageBus;

    // Maps chain ID to the bytes32 trusted addresses allowed to be source senders
    mapping(uint256 => bytes32) internal trustedRemoteLookup;

    event SetTrustedRemote(uint256 _srcChainId, bytes32 _srcAddress);


    /**
     * @notice Executes a message called by MessageBus (MessageBusReceiver)
     * @dev Must be called by MessageBug & sent from src chain by a trusted srcApp
     * @param _srcAddress The bytes32 address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     * @return status Enum containing options of Success, Fail, Retry
     */
    function executeMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external returns (MsgExecutionStatus) {
        // Must be called by the MessageBus/MessageBus for security
        require(msg.sender == messageBus, "caller is not message bus");
        // Must also be from a trusted source app
        require(_srcAddress == trustedRemoteLookup[_srcChainId], "Invalid source sending app");

        return _handleMessage(_srcAddress, _srcChainId, _message, _executor);
    }

    // Logic here handling messsage contents
    function _handleMessage(bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor) internal virtual returns (MsgExecutionStatus);


    function _send(bytes32 _receiver,
        uint256 _dstChainId,
        bytes memory _message,
        bytes memory _options) internal virtual {
            require(trustedRemoteLookup[_dstChainId] != bytes32(0));
            IMessageBus(messageBus).sendMessage{value: msg.value}(_receiver, _dstChainId, _message, _options);
    }

    //** Config Functions */
    function setMessageBus(address _messageBus) public onlyOwner {
        messageBus = _messageBus;
    }

     // allow owner to set trusted addresses allowed to be source senders
    function setTrustedRemote(uint256 _srcChainId, bytes32 _srcAddress) external onlyOwner {
        trustedRemoteLookup[_srcChainId] = _srcAddress;
        emit SetTrustedRemote(_srcChainId, _srcAddress);
    }

    //** View functions */
    function getTrustedRemote(uint256 _chainId) external view returns (bytes32 trustedRemote) {
        return trustedRemoteLookup[_chainId];
    }

}
