// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManageable {
    enum TxStatus {
        Null,
        Success,
        Fail
    }

    function updateMessageStatus(bytes32 messageId, TxStatus status) external;

    function updateAuthVerifier(address authVerifier) external;

    function withdrawGasFees(address payable to) external;

    function rescueGas(address payable to) external;

    function updateGasFeePricing(address gasFeePricing) external;

    function getExecutedMessage(bytes32 messageId) external view returns (TxStatus);
}
