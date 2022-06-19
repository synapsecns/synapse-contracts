// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseAaveAdapter} from "../abstract/SynapseAaveAdapter.sol";
import {AdapterFour} from "../../tokens/AdapterFour.sol";

// Need to store both pool and underlying tokens, so it's AdapterFour
contract SynapseAaveTwoAdapter is SynapseAaveAdapter, AdapterFour {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        address _lendingPool,
        address[] memory _underlyingTokens
    ) SynapseAaveAdapter(_name, _swapGasEstimate, _pool, _lendingPool, _underlyingTokens) {}
}
