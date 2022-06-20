// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveTriCryptoWrappedAdapter} from "../abstract/CurveTriCryptoWrappedAdapter.sol";
import {AdapterFive} from "../../tokens/AdapterFive.sol";

// Author was most certainly not on any substances, when picking a name for this contract.

/// @dev Adapter for TriCrypto pool which is using 3pool LP token as stable coin,
/// thus having the structure: [DAI, USDC, USDT, WBTC, WETH].
contract CurveTriCryptoWrappedFiveAdapter is CurveTriCryptoWrappedAdapter, AdapterFive {
    // solhint-disable no-empty-blocks
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported,
        address _basePool
    ) CurveTriCryptoWrappedAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported, _basePool) {}
}
