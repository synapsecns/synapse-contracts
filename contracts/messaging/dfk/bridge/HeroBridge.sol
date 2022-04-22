// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiver.sol";
import "../IHeroCoreUpgradeable.sol";
import {HeroStatus} from "../types/HeroTypes.sol";

pragma solidity 0.8.13;

/** @title Core app for handling cross chain messaging passing to bridge Hero NFTs
*/

contract HeroBridge is SynMessagingReceiver {
    address public heroes;

    constructor(address _messageBus, address _heroes) {
        messageBus = _messageBus;
        heroes = _heroes;
    }

    /** 
     * @notice User must have an existing hero minted to bridge it. 
     * @param heroId specifics which hero msg.sender already holds and will transfer to the bridge contract
     * @param _receiver The bytes32 address of the destination contract to be called
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     * @param _message The arbitrary payload to pass to the destination chain receiver
     * @param _options Versioned struct used to instruct relayer on how to proceed with gas limits
     */
    function sendHero(uint256 heroId, bytes32 _receiver, uint256 _dstChainId, bytes calldata _message, bytes calldata _options) external {
        // Transfer Hero IHeroCoreUpgradeable(heroes).safeTransferFrom(msg.sender, address(this), heroId);
        // Hero now locked, message can be safely emitted
        // _send(_receiver, _dstChainId, _message, _options);
    }

    // Function called by executeMessage() - handleMessage will handle the hero bridge mint 
    function _handleMessage(bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes calldata _message,
        address _executor) internal override returns (MsgExecutionStatus) {
            // Decode _message, depending on exactly how the originating message is structured

            /** 
             If hero ID doesn't exist: 
             1. Mint a hero with most recent atttributes from the message, and the correct hero ID
             2. Transfer the newly minted hero to msg.dstUserAddress
             3. Tx completed, return Success
             */


            /** 
             If heroId does exist (which means it should be locked on this contract), as it was bridged before.
             1. first update the hero attributes based on the attributes in the message (Assumes the message has more recent attributes)
             2. Then transfer it to message.dstUserAddress
             3. Tx completed, return Success
             */ 
        }

    
    function _send(bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options) internal override {
            require(trustedRemoteLookup[_dstChainId] != bytes32(0));
            IMessageBus(messageBus).sendMessage{value: msg.value}(_receiver, _dstChainId, _message, _options);
    }

}