// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseAdapter} from "../abstract/SynapseAdapter.sol";
import {AdapterTwo} from "../../tokens/AdapterTwo.sol";

contract SynapseBaseTwoAdapter is SynapseAdapter, AdapterTwo {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SynapseAdapter(_name, _swapGasEstimate, _pool) {}
}
