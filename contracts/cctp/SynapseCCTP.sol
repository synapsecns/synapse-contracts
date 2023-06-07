// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTPEvents} from "./events/SynapseCCTPEvents.sol";
import {IMessageTransmitter} from "./interfaces/IMessageTransmitter.sol";
import {ISynapseCCTP} from "./interfaces/ISynapseCCTP.sol";
import {ITokenMessenger} from "./interfaces/ITokenMessenger.sol";
import {RequestLib} from "./libs/Request.sol";

contract SynapseCCTP is SynapseCCTPEvents, ISynapseCCTP {
    // TODO: add setters for these (or make them immutable)
    uint32 public localDomain;
    IMessageTransmitter public messageTransmitter;
    ITokenMessenger public tokenMessenger;
    mapping(uint32 => bytes32) public remoteSynapseCCTP;

    /// @inheritdoc ISynapseCCTP
    function sendCircleToken(
        address recipient,
        uint32 destinationDomain,
        address burnToken,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) external {
        uint64 nonce = messageTransmitter.nextAvailableNonce();
        // This will revert if the request version is not supported, or swap params are not properly formatted.
        bytes memory formattedRequest = RequestLib.formatRequest(
            requestVersion,
            RequestLib.formatBaseRequest(localDomain, nonce, burnToken, amount, recipient),
            swapParams
        );
        // Construct the request identifier to be used as salt later.
        // The identifier (kappa) is unique for every single request on all the chains.
        // This is done by including origin and destination domains as well as origin nonce in the hashed data.
        // Origin domain and nonce are included in `formattedRequest`, so we only need to add the destination domain.
        bytes32 kappa = _kappa(destinationDomain, requestVersion, formattedRequest);
        tokenMessenger.depositForBurnWithCaller(
            amount,
            destinationDomain,
            remoteSynapseCCTP[destinationDomain],
            burnToken,
            _destinationCaller(destinationDomain, kappa)
        );
        emit CircleRequestSent(destinationDomain, nonce, requestVersion, formattedRequest, kappa);
    }

    // TODO: guard this to be only callable by the validators?
    /// @inheritdoc ISynapseCCTP
    function receiveCircleToken(
        bytes calldata message,
        bytes calldata signature,
        uint32 requestVersion,
        bytes memory formattedRequest
    ) external {
        (bytes memory baseRequest, bytes memory swapParams) = RequestLib.decodeRequest(
            requestVersion,
            formattedRequest
        );
        (uint32 originDomain, , address originBurnToken, uint256 amount, address recipient) = RequestLib
            .decodeBaseRequest(baseRequest);
        // For kappa hashing we use origin and destination domains as well as origin nonce.
        // This ensures that kappa is unique for each request, and that it is not possible to replay requests.
        bytes32 kappa = _kappa(localDomain, requestVersion, formattedRequest);
        // Kindly ask the Circle Bridge to mint the tokens for us.
        _mintCircleToken(message, signature, kappa);
        address token = _getMintedToken(originDomain, originBurnToken);
        uint256 fee;
        // Apply the bridging fee. This will revert if amount <= fee.
        (amount, fee) = _applyFee(token, amount);
        // Fulfill the request: perform an optional swap and send the end tokens to the recipient.
        _fulfillRequest(recipient, token, amount, swapParams);
        emit CircleRequestFulfilled(recipient, token, amount, fee, kappa);
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Applies the bridging fee. Will revert if amount <= fee.
    function _applyFee(address token, uint256 amount) internal returns (uint256 amountAfterFee, uint256 fee) {
        // TODO: implement
    }

    /// @dev Mints the Circle token by sending the message and signature to the Circle Bridge.
    function _mintCircleToken(
        bytes calldata message,
        bytes calldata signature,
        bytes32 kappa
    ) internal {
        // TODO: implement
    }

    /// @dev Performs a swap, if was requested back on origin chain, and transfers the tokens to the recipient.
    /// Should the swap fail, will transfer `token` to the recipient instead.
    function _fulfillRequest(
        address recipient,
        address token,
        uint256 amount,
        bytes memory swapParams
    ) internal {
        // TODO: implement
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Predicts the address of the destination caller.
    function _destinationCaller(uint32 destinationDomain, bytes32 kappa) internal view returns (bytes32) {
        // TODO: implement
    }

    /// @dev Fetches the address and the amount of the minted Circle token.
    function _getMintedToken(uint32 originDomain, address originBurnToken) internal view returns (address token) {
        // TODO: implement
    }

    /// @dev Calculates the unique identifier of the request.
    function _kappa(
        uint32 destinationDomain,
        uint32 requestVersion,
        bytes memory request
    ) internal pure returns (bytes32) {
        // TODO: implement
    }
}
