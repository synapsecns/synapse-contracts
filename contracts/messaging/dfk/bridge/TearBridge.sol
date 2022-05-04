// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiver.sol";

import "../inventory/IInventoryItem.sol";

contract TearBridge is SynMessagingReceiver {
        address public immutable gaiaTear;
        uint256 public msgGasLimit;

        struct MessageFormat {
        address dstUser;
        uint256 dstTearAmount;
    }
    
    event GaiaSent(address indexed dstUser, uint256 arrivalChainId);
    event GaiaArrived(address indexed dstUser, uint256 arrivalChainId);

    constructor(
        address _messageBus,
        address _gaiaTear
    ) {
        messageBus = _messageBus;
        gaiaTear = _gaiaTear; 
    }

    function _createMessage(
        address _dstUserAddress,
        uint256 _dstTearAmount
    ) internal pure returns (bytes memory) {
        // create the message here from the nested struct
        MessageFormat memory msgFormat = MessageFormat({
            dstUser: _dstUserAddress,
            dstTearAmount: _dstTearAmount
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

    function bridgeTears(uint256 _tearsAmount, uint256 _dstChainId) external payable {
        uint256 tearsAmount = _tearsAmount;
        uint256 dstChainId = _dstChainId;
        // Tears now burnt, equivalent amount will be bridged to dstChainId
        IInventoryItem(gaiaTear).burnFrom(msg.sender, tearsAmount);

        bytes32 receiver = trustedRemoteLookup[dstChainId];
        bytes memory message = _createMessage(msg.sender, tearsAmount);
        bytes memory options = _createOptions();

        _send(receiver, dstChainId, message, options);
        emit GaiaSent(msg.sender, tearsAmount);
    }

    // Function called by executeMessage() - handleMessage will handle the gaia tear mint
    // executeMessage() handles permissioning checks
    function _handleMessage(bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes memory _message,
        address _executor) internal override {
            MessageFormat memory passedMsg = _decodeMessage(_message);
            address dstUser = passedMsg.dstUser;
            uint256 dstTearAmount = passedMsg.dstTearAmount;
            IInventoryItem(gaiaTear).mint(dstUser, dstTearAmount);
            emit GaiaArrived(dstUser, dstTearAmount);
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


    function setMsgGasLimit(uint256 _msgGasLimit) external onlyOwner {
        msgGasLimit = _msgGasLimit;
    }
}