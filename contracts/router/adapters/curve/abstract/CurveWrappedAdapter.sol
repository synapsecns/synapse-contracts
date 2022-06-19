// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveBaseAdapter} from "./CurveBaseAdapter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

/**
 * @dev Base contract for Curve BasePool (with wrapped tokens) adapters:
 *      - indices: int128
 *      - swap method: exchange_underlying()
 */
abstract contract CurveWrappedAdapter is CurveBaseAdapter {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveBaseAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {} // solhint-disable-line no-empty-blocks

    function _setPoolTokensAllowance() internal virtual override {
        for (uint8 i = 0; true; i++) {
            try pool.underlying_coins(i) returns (address _tokenAddress) {
                _setInfiniteAllowance(IERC20(_tokenAddress), address(pool));
            } catch {
                break;
            }
        }
    }

    function _loadToken(uint256 index) internal view virtual override returns (address) {
        return pool.underlying_coins(index);
    }

    function _doDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = pool.exchange_underlying(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn, 0, _to);
    }

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = pool.exchange_underlying(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn, 0);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try pool.get_dy_underlying(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn) returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            _amountOut = 0;
        }
    }
}
