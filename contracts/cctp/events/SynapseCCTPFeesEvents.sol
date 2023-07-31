// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract SynapseCCTPFeesEvents {
    /// @notice Emitted when the fee collector is updated for a relayer
    /// @param relayer          The relayer address
    /// @param oldFeeCollector  The old fee collector address: will be able to withdraw prior fees
    /// @param newFeeCollector  The new fee collector address: will be able to withdraw future fees
    event FeeCollectorUpdated(address indexed relayer, address oldFeeCollector, address newFeeCollector);

    /// @notice Emitted when the fee for relaying a CCTP message is collected
    /// @dev If fee collector address is not set, the full fee is collected for the protocol
    /// @param feeCollector      The fee collector address
    /// @param relayerFeeAmount  The amount of fees collected for the relayer
    /// @param protocolFeeAmount The amount of fees collected for the protocol
    event FeeCollected(address feeCollector, uint256 relayerFeeAmount, uint256 protocolFeeAmount);

    /// @notice Emitted when the amount of native gas airdropped to recipients is updated
    /// @param chainGasAmount   The new amount of native gas airdropped to recipients
    event ChainGasAmountUpdated(uint256 chainGasAmount);

    /// @notice Emitted when the native chain gas is airdropped to a recipient
    event ChainGasAirdropped(uint256 amount);

    /// @notice Emitted when the protocol fee is updated
    /// @param newProtocolFee  The new protocol fee
    event ProtocolFeeUpdated(uint256 newProtocolFee);
}
