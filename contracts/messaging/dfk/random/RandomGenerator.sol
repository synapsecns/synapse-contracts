// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RandomInputs} from "../types/RandomTypes.sol";

contract RandomGenerator {
    constructor() {}
    function getRandom(RandomInputs memory _inputs) external returns (uint256) {
        return 10;   
    }
}