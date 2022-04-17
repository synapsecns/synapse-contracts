// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IMessageReceiverApp {

    /** 
     * @notice MsgExecutionStatus state
     * @return Success execution succeeded, finalized
     * @return Fail // execution failed, finalized
     * @return Retry // execution failed or rejected, set to be retryable
    */ 
    enum MsgExecutionStatus {
        Fail, 
        Success,
        Retry
    }

     /**
     * @notice Called by MessageBus (MessageBusReceiver)
     * @param _srcSender The bytes address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        bytes calldata _srcSender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (MsgExecutionStatus);
}
    