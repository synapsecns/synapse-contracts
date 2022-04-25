// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiver.sol";
import "../IHeroCoreUpgradeable.sol";
import {HeroStatus} from "../types/HeroTypes.sol";

pragma solidity 0.8.13;

/** @title Core app for handling cross chain messaging passing to bridge Hero NFTs
*/

contract HeroBridge is SynMessagingReceiver {
    address public heroes;
    
    struct MessageFormat {
        Hero dstHero;
        address dstUser;
        uint256 dstHeroId;

    }

    constructor(address _messageBus, address _heroes) {
        messageBus = _messageBus;
        heroes = _heroes;
    }

    function _createMessage(uint256 _heroId, address _dstUserAddress, Hero memory _heroToBridge) internal pure returns (bytes calldata {
        // create the message here from the nested struct
        MessageFormat memory msgFormat = MessageFormat({
            dstHeroId: _heroId,
            dstHero: _heroToBridge,
            dstUser: _dstUserAddress
        });
        return abi.encode(msgFormat);
    }

    function _decodeMessage(bytes calldata _message) internal pure returns (MessageFormat memory) {
        (MessageFormat memory decodedMessage) = abi.decode(_message, (MessageFormat));
        return decodedMessage;
    }

    /** 
     * @notice User must have an existing hero minted to bridge it. 
     * @param _heroId specifics which hero msg.sender already holds and will transfer to the bridge contract
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     */
    function sendHero(uint256 _heroId, uint256 _dstChainId) external payable {
        Hero memory heroToBridge = IHeroCoreUpgradeable(heroes).getHero(_heroId);
        bytes32 receiver = trustedRemoteLookup[_dstChainId];
        // _createMessage(heroId, dstUserAddress, Hero);
        bytes calldata msgToPass = _createMessage(_heroId, msg.sender, heroToBridge);
        // Create _options
        // temporarily empty
        bytes calldata options = bytes("");

        IHeroCoreUpgradeable(heroes).safeTransferFrom(msg.sender, address(this), _heroId);
        // Hero now locked, message can be safely emitted

        _send(receiver, _dstChainId, msgToPass, bytes(""));
    }

    // Function called by executeMessage() - handleMessage will handle the hero bridge mint 
    // executeMessage() handles permissioning checks
    function _handleMessage(bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes calldata _message,
        address _executor) internal override returns (MsgExecutionStatus) {
            // Decode _message, depending on exactly how the originating message is structured
            /** 
            Message data: 
                Hero memory heroToBridge = IHeroCoreUpgradeable(heroes).getHero(_heroId);
                address dstUserAddress = msg.sender;
                uint256 dstHeroId = _heroId;
                bytes32 receiver = trustedRemoteLookup[_dstChainId];
             */

            /** 
             If hero ID doesn't exist: 
             1. Mint a hero to msg.dstUserAddress with most recent attributes from the message, and the correct hero ID
             2. Tx completed, return Success
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
            require(trustedRemoteLookup[_dstChainId] == _receiver);
            IMessageBus(messageBus).sendMessage{value: msg.value}(_receiver, _dstChainId, _message, _options);
    }

}