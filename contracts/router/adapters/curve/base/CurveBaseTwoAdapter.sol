// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveBaseAdapter} from "../abstract/CurveBaseAdapter.sol";
import {AdapterTwo} from "../../tokens/AdapterTwo.sol";

/// @dev Adapter for Curve basepool with two tokens: [DAI, USDC].
/// Use Wrapped counterpart, if tokens in the pool are aTokens, or other kind of wrapped tokens.
contract CurveBaseTwoAdapter is CurveBaseAdapter, AdapterTwo {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveBaseAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {}
}
