// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable-4.5.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-4.5.0/security/PausableUpgradeable.sol";

import "./interfaces/IGasFeePricing.sol";
import "./ContextChainIdUpgradeable.sol";

contract MessageBusSenderUpgradeable is OwnableUpgradeable, PausableUpgradeable, ContextChainIdUpgradeable {
    address public gasFeePricing;
    uint64 public nonce;
    uint256 public fees;

    function __MessageBusSender_init(address _gasFeePricing) internal onlyInitializing {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __MessageBusSender_init_unchained(_gasFeePricing);
    }

    function __MessageBusSender_init_unchained(address _gasFeePricing) internal onlyInitializing {
        gasFeePricing = _gasFeePricing;
    }

    event MessageSent(
        address indexed sender,
        uint256 srcChainID,
        bytes32 receiver,
        uint256 indexed dstChainId,
        bytes message,
        uint64 nonce,
        bytes options,
        uint256 fee,
        bytes32 indexed messageId
    );

    function computeMessageId(
        address _srcAddress,
        uint256 _srcChainId,
        bytes32 _dstAddress,
        uint256 _dstChainId,
        uint256 _srcNonce,
        bytes calldata _message
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(_srcAddress, _srcChainId, _dstAddress, _dstChainId, _srcNonce, _message));
    }

    function estimateFee(uint256 _dstChainId, bytes calldata _options) public returns (uint256) {
        uint256 fee = IGasFeePricing(gasFeePricing).estimateGasFee(_dstChainId, _options);
        require(fee != 0, "Fee not set");
        return fee;
    }

    /**
     * @notice Sends a message to a receiving contract address on another chain.
     * Sender must make sure that the message is unique and not a duplicate message.
     * Unspent gas fees would be transferred back to tx.origin.
     * @param _receiver The bytes32 address of the destination contract to be called
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _message The arbitrary payload to pass to the destination chain receiver
     * @param _options Versioned struct used to instruct relayer on how to proceed with gas limits
     */
    function sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options
    ) external payable whenNotPaused {
        // use tx.origin for gas refund by default, so that older contracts,
        // interacting with MessageBus that don't have a fallback/receive
        // (i.e. not able to receive gas), will continue to work
        _sendMessage(_receiver, _dstChainId, _message, _options, payable(tx.origin));
    }

    /**
     * @notice Sends a message to a receiving contract address on another chain.
     * Sender must make sure that the message is unique and not a duplicate message.
     * Unspent gas fees will be refunded to specified address.
     * @param _receiver The bytes32 address of the destination contract to be called
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _message The arbitrary payload to pass to the destination chain receiver
     * @param _options Versioned struct used to instruct relayer on how to proceed with gas limits
     * @param _refundAddress Address that will receive unspent gas fees
     */
    function sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options,
        address payable _refundAddress
    ) external payable {
        _sendMessage(_receiver, _dstChainId, _message, _options, _refundAddress);
    }

    function _sendMessage(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options,
        address payable _refundAddress
    ) internal {
        uint256 srcChainId = _chainId();
        require(_dstChainId != srcChainId, "Invalid chainId");
        uint256 fee = estimateFee(_dstChainId, _options);
        require(msg.value >= fee, "Insufficient gas fee");
        bytes32 msgId = computeMessageId(msg.sender, srcChainId, _receiver, _dstChainId, nonce, _message);
        emit MessageSent(msg.sender, srcChainId, _receiver, _dstChainId, _message, nonce, _options, fee, msgId);
        fees += fee;
        ++nonce;
        // refund gas fees in case of overpayment
        if (msg.value > fee) {
            _refundAddress.transfer(msg.value - fee);
        }
    }

    /**
     * @notice Withdraws accumulated fees in native gas token, based on fees variable.
     * @param to Address to withdraw gas fees to, which can be specified in the event owner() can't receive native gas
     */
    function withdrawGasFees(address payable to) external onlyOwner {
        uint256 withdrawAmount = fees;
        // Reset fees to 0
        to.transfer(withdrawAmount);
        delete fees;
    }

    /**
     * @notice Rescues any gas in contract, aside from fees
     * @param to Address to which to rescue gas to
     */
    function rescueGas(address payable to) external onlyOwner {
        uint256 withdrawAmount = address(this).balance - fees;
        to.transfer(withdrawAmount);
    }

    function updateGasFeePricing(address _gasFeePricing) external onlyOwner {
        require(_gasFeePricing != address(0), "Cannot set to 0");
        gasFeePricing = _gasFeePricing;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
