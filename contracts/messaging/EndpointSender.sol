// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract EndpointSender is Ownable {

    constructor() public {

    }
    
    event MessageSent(address indexed sender, uint256 srcChainID, 
    bytes32 receiver, uint256 dstChainId, bytes messages, bytes options, uint256 fee);

    function estimateFee(bytes calldata _message, bytes calldata _options) public pure returns (uint256) {
        return 0;
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
    ) external {
        uint256 fee = estimateFee(_message, _options);
        emit MessageSent(msg.sender, block.chainid, _receiver, _dstChainId, _message, _options, fee);
    }
}
