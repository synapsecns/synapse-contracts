// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RandomInputs} from "../types/RandomTypes.sol";

interface IRandomGenerator {
    function getRandom(RandomInputs memory _inputs) external returns (uint256);
}
