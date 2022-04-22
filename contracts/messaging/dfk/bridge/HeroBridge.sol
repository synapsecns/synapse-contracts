// SPDX-License-Identifier: MIT

import "../../framework/SynMessagingReceiver.sol";
import "../IHeroCoreUpgradeable.sol";

pragma solidity 0.8.13;

/** @title Core app for handling cross chain messaging passing to bridge Hero NFTs
*/

contract HeroBridge is SynMessagingReceiver {

    constructor(address _messageBus) {
        messageBus = _messageBus;
    }

    // Logic here which will handle the hero bridge mint
    function _handleMessage(bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes calldata _message,
        address _executor) internal override returns (MsgExecutionStatus) {}

    
    function _send(bytes32 _receiver,
        uint256 _dstChainId,
        bytes calldata _message,
        bytes calldata _options) internal override {
            require(trustedRemoteLookup[_dstChainId] != bytes32(0));
            IMessageBus(messageBus).sendMessage{value: msg.value}(_receiver, _dstChainId, _message, _options);
    }

}