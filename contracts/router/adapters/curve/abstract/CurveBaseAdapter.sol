// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveAdapter} from "./CurveAdapter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts-4.5.0/utils/math/SafeCast.sol";

/**
 * @dev Base contract for Curve BasePool adapters:
 *      - indices: int128
 *      - swap method: exchange()
 */
abstract contract CurveBaseAdapter is CurveAdapter {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {} // solhint-disable-line no-empty-blocks

    function _castIndex(address _token) internal view returns (int128) {
        return int128(int256(_getIndex(_token)));
    }

    function _doDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = IERC20(_tokenOut).balanceOf(_to);
        pool.exchange(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn, 0, _to);
        _amountOut = IERC20(_tokenOut).balanceOf(_to) - _amountOut;
    }

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual override returns (uint256 _amountOut) {
        pool.exchange(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn, 0);
        // Imagine not returning amount of swapped tokens
        _amountOut = IERC20(_tokenOut).balanceOf(address(this));
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try pool.get_dy(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn) returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            _amountOut = 0;
        }
    }
}
