// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../interfaces/ISynMessagingReceiver.sol";
import "../interfaces/IMessageBus.sol";

contract PingPong is ISynMessagingReceiver {
    // MessageBus is responsible for sending messages to receiving apps and sending messages across chains
    IMessageBus public messageBus;
    // whether to ping and pong back and forth
    bool public pingsEnabled;
    // event emitted everytime it is pinged, counting number of pings
    event Ping(uint256 pings);
    // total pings in a loops
    uint256 public maxPings;
    uint256 public numPings;

    constructor(address _messageBus) {
        pingsEnabled = true;
        messageBus = IMessageBus(_messageBus);
        maxPings = 5;
    }

    function disable() external {
        pingsEnabled = false;
    }

    function ping(uint256 _dstChainId, address _dstPingPongAddr, uint256 pings) public {
        require(address(this).balance > 0, "the balance of this contract needs to be able to pay for native gas");
        require(pingsEnabled, "pingsEnabled is false. messages stopped");
        require(maxPings > pings, "maxPings has been reached, no more looping");

        emit Ping(pings);

        bytes memory message = abi.encode(pings);

        // this will have to be changed soon (WIP, options disabled)

        uint256 fee = messageBus.estimateFee(_dstChainId, bytes(""));
        require(address(this).balance >= fee, "not enough gas for fees");

        messageBus.sendMessage{value: fee}(
            bytes32(uint256(uint160(_dstPingPongAddr))), _dstChainId, message, bytes("")
        );
    }

    /**
     * @notice Called by MessageBus (MessageBusReceiver)
     * @param _srcAddress The bytes32 address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        bytes32 _srcAddress,
        uint256 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external returns (ISynMessagingReceiver.MsgExecutionStatus) {
        require(msg.sender == address(messageBus));
        // In production the srcAddress should be a verified sender

        address fromAddress = address(uint160(uint256(_srcAddress)));

        uint256 pings = abi.decode(_message, (uint256));

        // recursively call ping again upon pong
        ++pings;
        numPings = pings;

        ping(_srcChainId, fromAddress, pings);
        return ISynMessagingReceiver.MsgExecutionStatus.Success;
    }

    // allow this contract to receive ether
    fallback() external payable {}

    receive() external payable {}
}