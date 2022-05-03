// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiver.sol";
import "../IHeroCoreUpgradeable.sol";
import "../IAssistingAuctionUpgradeable.sol";
import {HeroStatus} from "../types/HeroTypes.sol";

pragma solidity 0.8.13;

/** @title Core app for handling cross chain messaging passing to bridge Hero NFTs
 */

contract HeroBridge is SynMessagingReceiver {
    address public heroes;
    address public assistingAuction;
    uint256 public msgGasLimit;

    struct MessageFormat {
        Hero dstHero;
        address dstUser;
        uint256 dstHeroId;
    }

    constructor(
        address _messageBus,
        address _heroes,
        address _assistingAuction
    ) {
        messageBus = _messageBus;
        heroes = _heroes;
        assistingAuction = _assistingAuction;
    }


    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) { 
        return this.onERC721Received.selector;
    }

    function _createMessage(
        uint256 _heroId,
        address _dstUserAddress,
        Hero memory _heroToBridge
    ) internal pure returns (bytes memory) {
        // create the message here from the nested struct
        MessageFormat memory msgFormat = MessageFormat({
            dstHeroId: _heroId,
            dstHero: _heroToBridge,
            dstUser: _dstUserAddress
        });
        return abi.encode(msgFormat);
    }

    function _decodeMessage(bytes memory _message)
        internal
        pure
        returns (MessageFormat memory)
    {
        MessageFormat memory decodedMessage = abi.decode(
            _message,
            (MessageFormat)
        );
        return decodedMessage;
    }

    function _createOptions() public returns (bytes memory) {
        abi.encodePacked(uint16(1), msgGasLimit);
    }

    /**
     * @notice User must have an existing hero minted to bridge it.
     * @param _heroId specifics which hero msg.sender already holds and will transfer to the bridge contract
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     */
    function sendHero(uint256 _heroId, uint256 _dstChainId) external payable {
        Hero memory heroToBridge = IHeroCoreUpgradeable(heroes).getHero(
            _heroId
        );
        bytes32 receiver = trustedRemoteLookup[_dstChainId];
        // _createMessage(heroId, dstUserAddress, Hero);
        bytes memory msgToPass = _createMessage(
            _heroId,
            msg.sender,
            heroToBridge
        );
        // Create _options
        // temporarily empty
        bytes memory options = _createOptions();

        // revert if the hero is on a quest
        require(
            heroToBridge.state.currentQuest == address(0),
            "hero is questing"
        );

        // revert if the hero is on auction
        require(
            (IAssistingAuction(assistingAuction).isOnAuction(_heroId)) == false,
            "assisting auction"
        );

        IHeroCoreUpgradeable(heroes).safeTransferFrom(
            msg.sender,
            address(this),
            _heroId
        );
        // Hero now locked, message can be safely emitted

        _send(receiver, _dstChainId, msgToPass, options);
    }

    // Function called by executeMessage() - handleMessage will handle the hero bridge mint
    // executeMessage() handles permissioning checks
    function _handleMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor
    ) internal override returns (MsgExecutionStatus) {
        // Decode _message, depending on exactly how the originating message is structured
        /** 
            Message data: 
                Hero memory heroToBridge = IHeroCoreUpgradeable(heroes).getHero(_heroId);
                address dstUserAddress = msg.sender;
                uint256 dstHeroId = _heroId;
             */
        MessageFormat memory passedMsg = _decodeMessage(_message);

        Hero memory dstHero = passedMsg.dstHero;
        address dstUser = passedMsg.dstUser;
        uint256 dstHeroId = passedMsg.dstHeroId;

        // will revert if non-existant Hero
        try IHeroCoreUpgradeable(heroes).ownerOf(dstHeroId) returns (
            address heroOwner
        ) {
            /** 
                If heroId does exist (which means it should be locked on this contract), as it was bridged before.
                Transfer it to message.dstUserAddress
                */

            if (heroOwner == address(this)) {
                IHeroCoreUpgradeable(heroes).safeTransferFrom(
                    address(this),
                    dstUser,
                    dstHeroId
                );
            }
        } catch {
            /** 
                If hero ID doesn't exist: 
                Mint a hero to msg.dstUserAddress
                */
            IHeroCoreUpgradeable(heroes).bridgeMint(dstHero, dstUser);
        }

        // update the hero attributes based on the attributes in the message (Assumes the message has more recent attributes)
        IHeroCoreUpgradeable(heroes).updateHero(dstHero);
        // Tx completed, return Success
        return MsgExecutionStatus.Success;
    }

    function _send(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes memory _message,
        bytes memory _options
    ) internal override {
        require(trustedRemoteLookup[_dstChainId] != bytes32(0));
        require(trustedRemoteLookup[_dstChainId] == _receiver);
        IMessageBus(messageBus).sendMessage{value: msg.value}(
            _receiver,
            _dstChainId,
            _message,
            _options
        );
    }

    function setAssistingAuctionAddress(address _assistingAuction) external onlyOwner {
        assistingAuction = _assistingAuction;
    }

    function setMsgGasLimit(uint256 _msgGasLimit) external onlyOwner {
        msgGasLimit = _msgGasLimit;
    }
}
