// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveMetaAdapter} from "../abstract/CurveMetaAdapter.sol";
import {AdapterFour} from "../../tokens/AdapterFour.sol";

/// @dev Adapter for Curve metapool, assuming basepool has three tokens.
/// For instance: [FRAX, DAI, USDC, USDT].
contract CurveMetaFourAdapter is CurveMetaAdapter, AdapterFour {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported,
        address _basePool
    ) CurveMetaAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported, _basePool) {}
}
