// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract MockCallRecipient {
    event CallReceived(address caller, bytes32 data);

    function callMeMaybe(bytes32 data) external returns (bytes32) {
        emit CallReceived(msg.sender, data);
        return transformData(data);
    }

    function transformData(bytes32 data) public pure returns (bytes32) {
        return data ^ bytes32(uint256(1));
    }
}
