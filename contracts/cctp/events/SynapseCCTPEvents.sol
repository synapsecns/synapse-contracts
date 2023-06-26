// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract SynapseCCTPEvents {
    /// @notice Emitted when a Circle token is sent with an attached action request.
    /// @dev To fulfill the request, the validator needs to fetch `message` from `MessageSent` event
    /// emitted by Circle's MessageTransmitter in the same tx, then fetch `signature` for the message from Circle API.
    /// This data will need to be presented to SynapseCCTP on the destination chain,
    /// along with `requestVersion` and `formattedRequest` emitted in this event.
    /// @param chainId              Chain ID of the destination chain
    /// @param sender               Sender of the CCTP tokens on origin chain
    /// @param nonce                Nonce of the CCTP message on origin chain
    /// @param token                Address of Circle token that was burnt
    /// @param amount               Amount of Circle tokens burnt
    /// @param requestVersion       Version of the request format
    /// @param formattedRequest     Formatted request for the action to take on the destination chain
    /// @param requestID            Unique identifier of the request
    event CircleRequestSent(
        uint256 chainId,
        address indexed sender,
        uint64 nonce,
        address token,
        uint256 amount,
        uint32 requestVersion,
        bytes formattedRequest,
        bytes32 requestID
    );

    /// @notice Emitted when a Circle token is received with an attached action request.
    /// @param originDomain         CCTP domain of the origin chain
    /// @param recipient            End recipient of the tokens on this chain
    /// @param mintToken            Address of the minted Circle token
    /// @param fee                  Fee paid for fulfilling the request, in minted tokens
    /// @param token                Address of token that recipient received
    /// @param amount               Amount of tokens received by recipient
    /// @param requestID            Unique identifier of the request
    event CircleRequestFulfilled(
        uint32 originDomain,
        address indexed recipient,
        address mintToken,
        uint256 fee,
        address token,
        uint256 amount,
        bytes32 requestID
    );
}
