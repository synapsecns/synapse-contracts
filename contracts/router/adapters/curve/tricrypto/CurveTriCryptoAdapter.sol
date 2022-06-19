// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveAdapter} from "../abstract/CurveAdapter.sol";
import {AdapterThree} from "../../tokens/AdapterThree.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

// Believe it or not, but a TriCrypto pool always has exactly three tokens inside.

/// @dev Adapter for TriCrypto pool, which usually has structure: [USDT, WBTC, WETH]
contract CurveTriCryptoAdapter is CurveAdapter, AdapterThree {
    // solhint-disable no-empty-blocks
    /**
     * @dev TriCrypto Adapter is using uint256 for indexes
     *      and is using exchange() for swaps.
     */

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {}

    function _doDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = IERC20(_tokenOut).balanceOf(_to);
        pool.exchange(_getIndex(_tokenIn), _getIndex(_tokenOut), _amountIn, 0, _to);
        _amountOut = IERC20(_tokenOut).balanceOf(_to) - _amountOut;
    }

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual override returns (uint256 _amountOut) {
        pool.exchange(_getIndex(_tokenIn), _getIndex(_tokenOut), _amountIn, 0);
        // Imagine not returning amount of swapped tokens
        _amountOut = IERC20(_tokenOut).balanceOf(address(this));
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try pool.get_dy(_getIndex(_tokenIn), _getIndex(_tokenOut), _amountIn) returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            _amountOut = 0;
        }
    }
}
