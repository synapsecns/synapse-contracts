// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseNexusAdapter} from "../abstract/SynapseNexusAdapter.sol";
import {AdapterFour} from "../../tokens/AdapterFour.sol";

contract SynapseBaseTwoAdapter is SynapseNexusAdapter, AdapterFour {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SynapseNexusAdapter(_name, _swapGasEstimate, _pool) {}
}
