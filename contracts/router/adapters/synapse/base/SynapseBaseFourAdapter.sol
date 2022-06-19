// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseAdapter} from "../abstract/SynapseAdapter.sol";
import {AdapterFour} from "../../tokens/AdapterFour.sol";

contract SynapseBaseFourAdapter is SynapseAdapter, AdapterFour {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SynapseAdapter(_name, _swapGasEstimate, _pool) {} // solhint-disable-line no-empty-blocks
}
