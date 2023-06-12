// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MinimalForwarderLib} from "../../../contracts/cctp/libs/MinimalForwarder.sol";

contract MinimalForwarderLibHarness {
    function deploy(bytes32 salt) public returns (address) {
        address forwarder = MinimalForwarderLib.deploy(salt);
        return forwarder;
    }

    function forwardCall(
        address forwarder,
        address target,
        bytes memory payload
    ) public returns (bytes memory) {
        bytes memory returnData = MinimalForwarderLib.forwardCall(forwarder, target, payload);
        return returnData;
    }

    function forwardCallWithValue(
        address forwarder,
        address target,
        bytes memory payload
    ) public payable returns (bytes memory) {
        bytes memory returnData = MinimalForwarderLib.forwardCallWithValue(forwarder, target, payload, msg.value);
        return returnData;
    }

    function predictAddress(address deployer, bytes32 salt) public pure returns (address) {
        address forwarder = MinimalForwarderLib.predictAddress(deployer, salt);
        return forwarder;
    }
}
