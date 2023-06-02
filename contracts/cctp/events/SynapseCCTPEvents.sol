// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract SynapseCCTPEvents {
    // TODO: figure out what we need to emit for the Explorer

    /// @notice Emitted when a Circle token is sent with an attached action request.
    /// @dev To fulfill the request, the validator needs to fetch `message` from `MessageSent` event
    /// emitted by Circle's MessageTransmitter in the same tx, then fetch `signature` for the message from Circle API.
    /// All this data will need to be presented to SynapseCCTP on the destination domain.
    /// @param destinationDomain    Domain of destination chain
    /// @param nonce                Nonce of the CCTP message on origin domain
    /// @param requestVersion       Version of the request format
    /// @param request              Request for the action to take on the destination domain
    /// @param kappa                Unique identifier of the request
    event CircleRequestSent(
        uint32 destinationDomain,
        uint64 nonce,
        uint32 requestVersion,
        bytes request,
        bytes32 indexed kappa
    );

    /// @notice Emitted when a Circle token is received with an attached action request.
    /// @param recipient            End recipient of the tokens on this domain
    /// @param token                Address of Circle token received on this domain
    /// @param amount               Amount of tokens received
    /// @param fee                  Fee paid for fulfilling the request
    /// @param kappa                Unique identifier of the request
    event CircleRequestFulfilled(
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 fee,
        bytes32 indexed kappa
    );
}
