// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract MockCallRecipient {
    event ValueCallReceived(address caller, bytes32 data, uint256 value);
    event CallReceived(address caller, bytes32 data);

    function callMeMaybe(bytes32 data) external returns (bytes32) {
        emit CallReceived(msg.sender, data);
        return transformData(data);
    }

    function valueCallMeMaybe(bytes32 data) external payable returns (bytes32) {
        emit ValueCallReceived(msg.sender, data, msg.value);
        return transformData(data);
    }

    function transformData(bytes32 data) public pure returns (bytes32) {
        return data ^ bytes32(uint256(1));
    }
}
