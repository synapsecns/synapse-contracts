// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiverUpgradeable.sol";
import "../IPetCoreUpgradeable.sol";
import {Pet} from "../types/PetTypes.sol";

import "@openzeppelin/contracts-upgradeable-4.5.0/proxy/utils/Initializable.sol";

pragma solidity 0.8.13;

/** @title Core app for handling cross chain messaging passing to bridge Pet NFTs
 */

contract PetBridgeUpgradeable is Initializable, SynMessagingReceiverUpgradeable {
    address public pets;
    uint256 public msgGasLimit;

    struct MessageFormat {
        Pet dstPet;
        address dstUser;
        uint256 dstPetId;
    }

    function initialize(address _messageBus, address _pets) external initializer {
        __Ownable_init_unchained();
        messageBus = _messageBus;
        pets = _pets;
    }

    event PetSent(uint256 indexed petId, uint256 arrivalChainId);
    event PetArrived(uint256 indexed petId, uint256 arrivalChainId);

    function _createMessage(
        uint256 _petId,
        address _dstUserAddress,
        Pet memory _petToBridge
    ) internal pure returns (bytes memory) {
        // create the message here from the nested struct
        MessageFormat memory msgFormat = MessageFormat({
            dstPetId: _petId,
            dstPet: _petToBridge,
            dstUser: _dstUserAddress
        });
        return abi.encode(msgFormat);
    }

    function _decodeMessage(bytes memory _message) internal pure returns (MessageFormat memory) {
        MessageFormat memory decodedMessage = abi.decode(_message, (MessageFormat));
        return decodedMessage;
    }

    function _createOptions() internal view returns (bytes memory) {
        return abi.encodePacked(uint16(1), msgGasLimit);
    }

    /**
     * @notice User must have an existing pet minted to bridge it.
     * @dev This function enforces the caller to receive the Pet being bridged to the same address on another chain.
     * @dev Do NOT call this from other contracts, unless the contract is deployed on another chain to the same address,
     * @dev and can receive ERC721s.
     * @param _petId specifics which pet msg.sender already holds and will transfer to the bridge contract
     * @param _dstChainId The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains
     */
    function sendPet(uint256 _petId, uint256 _dstChainId) external payable {
        uint256 petId = _petId;
        uint256 dstChainId = _dstChainId;
        Pet memory petToBridge = IPetCoreUpgradeable(pets).getPet(petId);
        // revert if the pet is equipped
        require(petToBridge.equippedTo == 0, "pet is equipped");

        bytes32 receiver = trustedRemoteLookup[dstChainId];
        // _createMessage(petId, dstUserAddress, Pet);
        // Only bridgeable directly to the caller of this contract
        // @dev do not call this function from other contracts
        bytes memory msgToPass = _createMessage(petId, msg.sender, petToBridge);
        // Create _options
        bytes memory options = _createOptions();

        IPetCoreUpgradeable(pets).transferFrom(msg.sender, address(this), petId);
        require(IPetCoreUpgradeable(pets).ownerOf(petId) == address(this), "Failed to lock Pet");
        // Pet now locked, message can be safely emitted

        _send(receiver, dstChainId, msgToPass, options);
        emit PetSent(petId, dstChainId);
    }

    // Function called by executeMessage() - handleMessage will handle the pet bridge mint
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
                Pet memory petToBridge = IPetCoreUpgradeable(pets).getPet(_petId);
                address dstUserAddress = msg.sender;
                uint256 dstPetId = _petId;
             */
        MessageFormat memory passedMsg = _decodeMessage(_message);

        Pet memory dstPet = passedMsg.dstPet;
        address dstUser = passedMsg.dstUser;
        uint256 dstPetId = passedMsg.dstPetId;

        // will revert if non-existent Pet
        try IPetCoreUpgradeable(pets).ownerOf(dstPetId) returns (address petOwner) {
            /** 
                If petId does exist (which means it should be locked on this contract), as it was bridged before.
                Transfer it to message.dstUserAddress
                */

            if (petOwner == address(this)) {
                IPetCoreUpgradeable(pets).safeTransferFrom(address(this), dstUser, dstPetId);
            }
        } catch {
            /** 
                If pet ID doesn't exist: 
                Mint a pet to msg.dstUserAddress
                */
            IPetCoreUpgradeable(pets).bridgeMint(dstPetId, dstUser);
        }

        // update the pet attributes based on the attributes in the message (Assumes the message has more recent attributes)
        IPetCoreUpgradeable(pets).updatePet(dstPet);
        // Tx completed, emit success
        emit PetArrived(dstPetId, block.chainid);
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
        IMessageBus(messageBus).sendMessage{value: msg.value}(_receiver, _dstChainId, _message, _options);
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
