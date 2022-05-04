// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import "./interfaces/IGasFeePricing.sol";

contract MessageBusSender is Ownable {
    address public gasFeePricing;
    uint64 public nonce;
    uint256 internal fees;

    constructor(address _gasFeePricing) {
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

    function computeMessageIdSender(
        uint256 _srcChainId,
        address _srcAddress,
        uint256 _dstChainId,
        bytes32 _dstAddress,
        uint256 _nonce,
        bytes calldata _message
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _srcChainId,
                    _srcAddress,
                    _dstChainId,
                    _dstAddress,
                    _nonce,
                    _message
                )
            );
    }

    function estimateFee(uint256 _dstChainId, bytes calldata _options)
        public
        returns (uint256)
    {
        uint256 fee = IGasFeePricing(gasFeePricing).estimateGasFee(
            _dstChainId,
            _options
        );
        require(fee != 0, "Fee not set");
        return fee;
    }

    /**
     * @notice Sends a message to a receiving contract address on another chain.
     * Sender must make sure that the message is unique and not a duplicate message.
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
    ) external payable {
        require(_dstChainId != block.chainid, "Invalid chainId");
        uint256 fee = estimateFee(_dstChainId, _options);
        require(msg.value >= fee, "Insuffient gas fee");
        bytes32 msgId = computeMessageIdSender(
            block.chainid,
            msg.sender,
            _dstChainId,
            _receiver,
            nonce,
            _message
        );
        emit MessageSent(
            msg.sender,
            block.chainid,
            _receiver,
            _dstChainId,
            _message,
            nonce,
            _options,
            msg.value,
            msgId
        );
        fees += msg.value;
        ++nonce;
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

    function updateGasFeePricing(address _gasFeePricing) public onlyOwner {
        require(_gasFeePricing != address(0), "Cannot set to 0");
        gasFeePricing = _gasFeePricing;
    }
}
