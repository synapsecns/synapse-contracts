// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {RemoteCCTPTokenNotSet} from "./libs/Errors.sol";
import {SynapseCCTPEvents} from "./events/SynapseCCTPEvents.sol";
import {IMessageTransmitter} from "./interfaces/IMessageTransmitter.sol";
import {ISynapseCCTP} from "./interfaces/ISynapseCCTP.sol";
import {ITokenMinter} from "./interfaces/ITokenMinter.sol";
import {ITokenMessenger} from "./interfaces/ITokenMessenger.sol";
import {RequestLib} from "./libs/Request.sol";
import {MinimalForwarderLib} from "./libs/MinimalForwarder.sol";
import {TypeCasts} from "./libs/TypeCasts.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract SynapseCCTP is SynapseCCTPEvents, ISynapseCCTP {
    using MinimalForwarderLib for address;
    using SafeERC20 for IERC20;
    using TypeCasts for address;
    using TypeCasts for bytes32;

    uint32 public immutable localDomain;
    IMessageTransmitter public immutable messageTransmitter;
    ITokenMessenger public immutable tokenMessenger;

    // TODO: onlyOwner setters for these
    mapping(uint32 => bytes32) public remoteSynapseCCTP;
    mapping(uint256 => address) internal _remoteTokenIdToLocalToken;

    constructor(ITokenMessenger tokenMessenger_) {
        tokenMessenger = tokenMessenger_;
        messageTransmitter = IMessageTransmitter(tokenMessenger_.localMessageTransmitter());
        localDomain = messageTransmitter.localDomain();
    }

    // ═════════════════════════════════════════════ SET CONFIG LOGIC ══════════════════════════════════════════════════

    /// @notice Sets the local token associated with the given remote domain and token.
    // TODO: add ownerOnly modifier
    function setLocalToken(uint32 remoteDomain, address remoteToken) external {
        ITokenMinter minter = ITokenMinter(tokenMessenger.localMinter());
        // TODO: add address(0) check
        _remoteTokenIdToLocalToken[_remoteTokenId(remoteDomain, remoteToken)] = minter.getLocalToken(
            remoteDomain,
            remoteToken.addressToBytes32()
        );
    }

    /// @notice Sets the remote deployment of SynapseCCTP for the given remote domain.
    // TODO: add ownerOnly modifier
    function setRemoteSynapseCCTP(uint32 remoteDomain, address remoteSynapseCCTP_) external {
        // TODO: add zero checks
        remoteSynapseCCTP[remoteDomain] = remoteSynapseCCTP_.addressToBytes32();
    }

    // ════════════════════════════════════════════════ CCTP LOGIC ═════════════════════════════════════════════════════

    /// @inheritdoc ISynapseCCTP
    function sendCircleToken(
        address recipient,
        uint32 destinationDomain,
        address burnToken,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) external {
        // Pull token from user and update the amount in case of transfer fee.
        amount = _pullToken(burnToken, amount);
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
        bytes32 dstSynapseCCTP = remoteSynapseCCTP[destinationDomain];
        bytes32 kappa = _kappa(destinationDomain, requestVersion, formattedRequest);
        // Issue allowance if needed
        _approveToken(burnToken, amount);
        tokenMessenger.depositForBurnWithCaller(
            amount,
            destinationDomain,
            dstSynapseCCTP,
            burnToken,
            _destinationCaller(dstSynapseCCTP.bytes32ToAddress(), kappa)
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
        address token = _getLocalMintedToken(originDomain, originBurnToken);
        uint256 fee;
        // Apply the bridging fee. This will revert if amount <= fee.
        (amount, fee) = _applyFee(token, amount);
        // Fulfill the request: perform an optional swap and send the end tokens to the recipient.
        _fulfillRequest(recipient, token, amount, swapParams);
        emit CircleRequestFulfilled(recipient, token, amount, fee, kappa);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @notice Get the local token associated with the given remote domain and token.
    function getLocalToken(uint32 remoteDomain, address remoteToken) external view returns (address) {
        return _remoteTokenIdToLocalToken[_remoteTokenId(remoteDomain, remoteToken)];
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Applies the bridging fee. Will revert if amount <= fee.
    function _applyFee(address token, uint256 amount) internal returns (uint256 amountAfterFee, uint256 fee) {
        // TODO: implement actual fee logic
        return (amount, 0);
    }

    /// @dev Approves the token to be transferred to the Circle Bridge.
    function _approveToken(address token, uint256 amount) internal {
        uint256 allowance = IERC20(token).allowance(address(this), address(tokenMessenger));
        if (allowance < amount) {
            // Reset allowance to 0 before setting it to the new value.
            if (allowance != 0) IERC20(token).safeApprove(address(tokenMessenger), 0);
            IERC20(token).safeApprove(address(tokenMessenger), type(uint256).max);
        }
    }

    /// @dev Pulls the token from the sender.
    function _pullToken(address token, uint256 amount) internal returns (uint256 amountPulled) {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        amountPulled = IERC20(token).balanceOf(address(this)) - balanceBefore;
    }

    /// @dev Mints the Circle token by sending the message and signature to the Circle Bridge.
    function _mintCircleToken(
        bytes calldata message,
        bytes calldata signature,
        bytes32 kappa
    ) internal {
        // Deploy a forwarder specific to this request. Will revert if the kappa has been used before.
        address forwarder = MinimalForwarderLib.deploy(kappa);
        // Form the payload for the Circle Bridge.
        bytes memory payload = abi.encodeWithSelector(IMessageTransmitter.receiveMessage.selector, message, signature);
        // Use the deployed forwarder (who is the only one who can call the Circle Bridge for this message)
        // This will revert if the provided message is not properly formatted, or if the signatures are invalid.
        forwarder.forwardCall(address(messageTransmitter), payload);
    }

    /// @dev Performs a swap, if was requested back on origin chain, and transfers the tokens to the recipient.
    /// Should the swap fail, will transfer `token` to the recipient instead.
    function _fulfillRequest(
        address recipient,
        address token,
        uint256 amount,
        bytes memory swapParams
    ) internal {
        // TODO: implement swap logic
        IERC20(token).safeTransfer(recipient, amount);
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Fetches the address and the amount of the minted Circle token.
    function _getLocalMintedToken(uint32 originDomain, address originBurnToken) internal view returns (address token) {
        // Map the remote token to the local token.
        token = _remoteTokenIdToLocalToken[_remoteTokenId(originDomain, originBurnToken)];
        if (token == address(0)) revert RemoteCCTPTokenNotSet();
    }

    /// @dev Predicts the address of the destination caller that will be used to call the Circle Message Transmitter.
    function _destinationCaller(address synapseCCTP, bytes32 kappa) internal pure returns (bytes32) {
        return synapseCCTP.predictAddress(kappa).addressToBytes32();
    }

    /// @dev Calculates the unique identifier of the request.
    function _kappa(
        uint32 destinationDomain,
        uint32 requestVersion,
        bytes memory formattedRequest
    ) internal pure returns (bytes32 kappa) {
        // Merge the destination domain and the request version into a single uint256.
        uint256 prefix = (uint256(destinationDomain) << 32) | requestVersion;
        bytes32 requestHash = keccak256(formattedRequest);
        // Use assembly to return hash of the prefix and the request hash.
        // We are using scratch space to avoid unnecessary memory expansion.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Store prefix in memory at 0, and requestHash at 32.
            mstore(0, prefix)
            mstore(32, requestHash)
            // Return hash of first 64 bytes of memory.
            kappa := keccak256(0, 64)
        }
    }

    /// @dev Packs the domain and the token into a single uint256 value using bitwise operations.
    function _remoteTokenId(uint32 remoteDomain, address remoteToken) internal pure returns (uint256) {
        return (uint256(remoteDomain) << 160) | uint160(remoteToken);
    }
}
