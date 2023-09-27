// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IMessageTransmitter} from "./IMessageTransmitter.sol";

interface ISynapseCCTPConfig {
    /// @notice Struct defining the configuration of a remote domain that has SynapseCCTP deployed.
    /// @dev CCTP uses the following convention for domain numbers:
    /// - 0: Ethereum Mainnet
    /// - 1: Avalanche Mainnet
    /// With more chains added, the convention will be extended.
    /// @param domain       Value for the remote domain used in CCTP messages.
    /// @param synapseCCTP  Address of the SynapseCCTP deployed on the remote chain.
    struct DomainConfig {
        uint32 domain;
        address synapseCCTP;
    }

    /// @notice Refers to the local domain number used in CCTP messages.
    function localDomain() external view returns (uint32);

    /// @notice (chainId => configuration of the remote chain)
    function remoteDomainConfig(uint256 chainId) external view returns (DomainConfig memory);

    function messageTransmitter() external view returns (IMessageTransmitter);
}
