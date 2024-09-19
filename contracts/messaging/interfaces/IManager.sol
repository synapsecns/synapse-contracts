// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IManageable} from "./IManageable.sol";

interface IManager is IManageable {
    function resetFailedMessages(bytes32[] calldata messageIds) external;

    function transferMessageBusOwnership(address newOwner) external;
}
