// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseAdapter} from "../abstract/SynapseAdapter.sol";
import {AdapterThree} from "../../tokens/AdapterThree.sol";

contract SynapseBaseThreeAdapter is SynapseAdapter, AdapterThree {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SynapseAdapter(_name, _swapGasEstimate, _pool) {}
}
