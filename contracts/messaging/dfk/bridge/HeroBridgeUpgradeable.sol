// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiverUpgradeable.sol";
import "../IHeroCoreUpgradeable.sol";
import "../IAssistingAuctionUpgradeable.sol";
import {HeroStatus} from "../types/HeroTypes.sol";

import "@openzeppelin/contracts-upgradeable-4.5.0/proxy/utils/Initializable.sol";

pragma solidity 0.8.13;

/** @title Core app for handling cross chain messaging passing to bridge Hero NFTs
 */

contract HeroBridgeUpgradeable is Initializable, SynMessagingReceiverUpgradeable {
    address public heroes;
    address public assistingAuction;
    uint256 public msgGasLimit;

    struct MessageFormat {
        Hero dstHero;
        address dstUser;
        uint256 dstHeroId;
    }

    function initialize(address _messageBus,
        address _heroes,
        address _assistingAuction) external initializer {
        __Ownable_init_unchained();
        messageBus = _messageBus;
        heroes = _heroes;
        assistingAuction = _assistingAuction;
        }

    event HeroSent(uint256 indexed heroId, uint256 arrivalChainId);
    event HeroArrived(uint256 indexed heroId, uint256 arrivalChainId);

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

    function _createOptions() internal view returns (bytes memory) {
        return abi.encodePacked(uint16(1), msgGasLimit);
    }

    /**
     * @notice User must have an existing hero minted to bridge it.
     * @dev This function enforces the caller to receive the Hero being bridged to the same address on another chain.
     * @dev Do NOT call this from other contracts, unless the contract is deployed on another chain to the same address, 
     * @dev and can receive ERC721s. 
     * @param _heroId specifics which hero msg.sender already holds and will transfer to the bridge contract
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     */
    function sendHero(uint256 _heroId, uint256 _dstChainId) external payable {
        uint256 heroId = _heroId;
        uint256 dstChainId = _dstChainId;
        Hero memory heroToBridge = IHeroCoreUpgradeable(heroes).getHero(
            heroId
        );
        // revert if the hero is on a quest
        require(
            heroToBridge.state.currentQuest == address(0),
            "hero is questing"
        );

        // revert if the hero is on auction
        require(
            (IAssistingAuction(assistingAuction).isOnAuction(heroId)) == false,
            "assisting auction"
        );

        bytes32 receiver = trustedRemoteLookup[dstChainId];
        // _createMessage(heroId, dstUserAddress, Hero);
        // Only bridgeable directly to the caller of this contract
        // @dev do not call this function from other contracts
        bytes memory msgToPass = _createMessage(
            heroId,
            msg.sender,
            heroToBridge
        );
        // Create _options
        bytes memory options = _createOptions();

        IHeroCoreUpgradeable(heroes).transferFrom(
            msg.sender,
            address(this),
            heroId
        );
        require(IHeroCoreUpgradeable(heroes).ownerOf(heroId) == address(this), "Failed to lock Hero");
        // Hero now locked, message can be safely emitted

        _send(receiver, dstChainId, msgToPass, options);
        emit HeroSent(heroId, dstChainId);
    }

    // Function called by executeMessage() - handleMessage will handle the hero bridge mint
    // executeMessage() handles permissioning checks
    function _handleMessage(
        bytes32,
        uint256,
        bytes memory _message,
        address
    ) internal override {
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

        // will revert if non-existent Hero
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
            IHeroCoreUpgradeable(heroes).bridgeMint(dstHeroId, dstUser);
        }

        // update the hero attributes based on the attributes in the message (Assumes the message has more recent attributes)
        IHeroCoreUpgradeable(heroes).updateHero(dstHero);
        // Tx completed, emit success
        emit HeroArrived(dstHeroId, block.chainid);
    }

    function _send(
        bytes32 _receiver,
        uint256 _dstChainId,
        bytes memory _message,
        bytes memory _options
    ) internal override {
        bytes32 trustedRemote = trustedRemoteLookup[_dstChainId];
        require(trustedRemote != bytes32(0), "No remote app set for dst chain");
        require(trustedRemote == _receiver, "Receiver is not in trusted remote apps");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
