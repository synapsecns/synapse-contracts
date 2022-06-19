// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveBaseAdapter} from "../abstract/CurveBaseAdapter.sol";
import {AdapterThree} from "../../tokens/AdapterThree.sol";

/// @dev Adapter for Curve basepool with three tokens: [DAI, USDC, USDT].
/// Use Wrapped counterpart, if tokens in the pool are aTokens, or other kind of wrapped tokens.
contract CurveBaseThreeAdapter is CurveBaseAdapter, AdapterThree {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveBaseAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {}
}
