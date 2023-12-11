// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger} from "./ITokenMessenger.sol";
import {ISynapseCCTPFees} from "./ISynapseCCTPFees.sol";

interface ISynapseCCTP is ISynapseCCTPFees {
    /// @notice Send a Circle token supported by CCTP to a given chain
    /// with the request for the action to take on the destination chain.
    /// @dev The request is a bytes array containing information about the end recipient of the tokens,
    /// as well as an optional swap action to take on the destination chain.
    /// `chainId` refers to value from EIP-155 (block.chainid).
    /// @param recipient            Recipient of the tokens on destination chain
    /// @param chainId              Chain ID of the destination chain
    /// @param burnToken            Address of Circle token to burn
    /// @param amount               Amount of tokens to burn
    /// @param requestVersion       Version of the request format
    /// @param swapParams           Swap parameters for the action to take on the destination chain (could be empty)
    function sendCircleToken(
        address recipient,
        uint256 chainId,
        address burnToken,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) external;

    /// @notice Receive  Circle token supported by CCTP with the request for the action to take.
    /// @dev The request is a bytes array containing information about the end recipient of the tokens,
    /// as well as an optional swap action to take on this chain.
    /// @dev The relayers need to use SynapseCCTP.chainGasAmount() as `msg.value` when calling this function,
    /// or the call will revert.
    /// @param message              Message raw bytes emitted by CCTP MessageTransmitter on origin chain
    /// @param signature            Circle's attestation for the message obtained from Circle's API
    /// @param requestVersion       Version of the request format
    /// @param formattedRequest     Formatted request for the action to take on this chain
    function receiveCircleToken(
        bytes calldata message,
        bytes calldata signature,
        uint32 requestVersion,
        bytes memory formattedRequest
    ) external payable;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @notice Returns the whitelisted liquidity pool for a given Circle token.
    /// @dev Returns address(0) if the token bridge+swap is not supported.
    function circleTokenPool(address token) external view returns (address pool);

    /// @notice Returns the address of Circle's TokenMessenger contract used for bridging Circle tokens.
    function tokenMessenger() external view returns (ITokenMessenger);
}
