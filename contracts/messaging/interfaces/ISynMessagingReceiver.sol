// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface ISynMessagingReceiver {

    // Maps chain ID to the bytes32 trusted addresses allowed to be source senders
    // mapping(uint256 => bytes32) internal trustedRemoteLookup;


    /** 
     * @notice MsgExecutionStatus state
     * @return Success execution succeeded, finalized
     * @return Fail // execution failed, finalized
     * @return Retry // execution failed or rejected, set to be retryable
    */ 
    enum MsgExecutionStatus {
        Success, 
        Fail,
        Retry
    }

     /**
     * @notice Called by MessageBus 
     * @dev MUST be permissioned to trusted source apps via trustedRemote
     * @param _srcAddress The bytes32 address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external returns (MsgExecutionStatus);
}
    