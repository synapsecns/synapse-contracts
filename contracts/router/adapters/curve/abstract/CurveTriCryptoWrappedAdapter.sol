// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveAdapter} from "./CurveAdapter.sol";

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

/**
 * @dev Base contract for Curve TriCryptoPool (with wrapped tokens) adapters:
 *      - indices: uint256
 *      - swap method: exchange_underlying()
 *      Note: It is assumed that LP token for BasePool is used as the
 *      stablecoin in this pool.
 */
abstract contract CurveTriCryptoWrappedAdapter is CurveAdapter {
    uint256 private immutable numberStablecoins;
    ICurvePool private immutable basePool;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported,
        address _basePool
    ) CurveAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {
        basePool = ICurvePool(_basePool);
        numberStablecoins = _getBasePoolSize();
    }

    function _setPoolTokensAllowance() internal virtual override {
        for (uint8 i = 0; true; i++) {
            try pool.underlying_coins(i) returns (address _tokenAddress) {
                _setInfiniteAllowance(IERC20(_tokenAddress), address(pool));
            } catch {
                break;
            }
        }
    }

    function _getBasePoolSize() internal view returns (uint256 _numCoins) {
        _numCoins = 0;
        for (;;) {
            try basePool.coins(_numCoins) {
                _numCoins++;
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
        _amountOut = IERC20(_tokenOut).balanceOf(_to);
        pool.exchange_underlying(_getIndex(_tokenIn), _getIndex(_tokenOut), _amountIn, 0, _to);
        _amountOut = IERC20(_tokenOut).balanceOf(_to) - _amountOut;
    }

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual override returns (uint256 _amountOut) {
        pool.exchange_underlying(_getIndex(_tokenIn), _getIndex(_tokenOut), _amountIn, 0);
        // Imagine not returning amount of swapped tokens
        _amountOut = IERC20(_tokenOut).balanceOf(address(this));
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try pool.get_dy_underlying(_getIndex(_tokenIn), _getIndex(_tokenOut), _amountIn) returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            return 0;
        }

        // quote for swaps from [base pool token] to [meta pool token] is
        // sometimes overly optimistic. Subtracting 4 bp should give
        // a more accurate lower bound for actual amount of tokens swapped
        if (_getIndex(_tokenIn) < numberStablecoins) {
            _amountOut = (_amountOut * 9996) / 10000;
        }
    }
}
