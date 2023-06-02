// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISynapseCCTP {
    /// @notice Send a Circle token supported by CCTP to a given domain
    /// with the request for the action to take on the destination domain.
    /// @dev The request is a bytes array containing information about the end recipient of the tokens,
    /// as well as an optional swap action to take on the destination domain.
    /// @param destinationDomain    Domain of destination chain
    /// @param burnToken            Address of Circle token to burn
    /// @param amount               Amount of tokens to burn
    /// @param requestVersion       Version of the request format
    /// @param request              Request for the action to take on the destination domain
    function sendCircleToken(
        uint32 destinationDomain,
        address burnToken,
        uint256 amount,
        uint32 requestVersion,
        bytes memory request
    ) external;

    /// @notice Receive  Circle token supported by CCTP with the request for the action to take.
    /// @dev The request is a bytes array containing information about the end recipient of the tokens,
    /// as well as an optional swap action to take on this domain.
    /// @param message              Message raw bytes emitted by CCTP MessageTransmitter on origin domain
    /// @param signature            Circle's attestation for the message obtained from Circle's API
    /// @param requestVersion       Version of the request format
    /// @param request              Request for the action to take on this domain
    function receiveCircleToken(
        bytes calldata message,
        bytes calldata signature,
        uint32 requestVersion,
        bytes memory request
    ) external;
}
