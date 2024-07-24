// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";

contract MockSenderContract {
    function doCall(address target, bytes memory data) external payable {
        Address.functionCallWithValue(target, data, msg.value);
    }
}
