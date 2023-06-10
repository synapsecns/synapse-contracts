// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract SynapseCCTPFeesEvents {
    /// @notice Emitted when the fee collector is updated for a relayer
    /// @param relayer          The relayer address
    /// @param oldFeeCollector  The old fee collector address: will be able to withdraw prior fees
    /// @param newFeeCollector  The new fee collector address: will be able to withdraw future fees
    event FeeCollectorUpdated(address indexed relayer, address oldFeeCollector, address newFeeCollector);
}
