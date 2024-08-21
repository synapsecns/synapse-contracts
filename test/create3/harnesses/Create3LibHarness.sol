// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Create3Lib} from "../../../contracts/create3/libs/Create3.sol";

contract Create3LibHarness {
    function create3(
        bytes32 salt,
        bytes memory creationCode,
        uint256 value
    ) external payable returns (address) {
        return Create3Lib.create3(salt, creationCode, value);
    }

    function predictAddress(bytes32 salt) external view returns (address) {
        return Create3Lib.predictAddress(salt);
    }
}
