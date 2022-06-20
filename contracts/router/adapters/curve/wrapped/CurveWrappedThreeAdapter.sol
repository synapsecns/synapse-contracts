// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveWrappedAdapter} from "../abstract/CurveWrappedAdapter.sol";
import {AdapterThree} from "../../tokens/AdapterThree.sol";

/// @dev Adapter for Cure 3pool with wrapped tokens. For instance: [aDAI, aUSDC, aUSDT].
contract CurveWrappedThreeAdapter is CurveWrappedAdapter, AdapterThree {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveWrappedAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {}
}
