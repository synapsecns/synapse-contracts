// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MinimalForwarderLib} from "../../../contracts/cctp/libs/MinimalForwarder.sol";

contract MinimalForwarderLibHarness {
    function deploy(bytes32 salt) public returns (address forwarder) {
        forwarder = MinimalForwarderLib.deploy(salt);
    }

    function forwardCall(
        address forwarder,
        address target,
        bytes memory payload
    ) public returns (bytes memory returnData) {
        returnData = MinimalForwarderLib.forwardCall(forwarder, target, payload);
    }

    function predictAddress(address deployer, bytes32 salt) public pure returns (address forwarder) {
        forwarder = MinimalForwarderLib.predictAddress(deployer, salt);
    }
}
