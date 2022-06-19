// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveWrappedAdapter} from "./CurveWrappedAdapter.sol";

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

/**
 * @dev Base contract for Curve MetaPool adapters:
 *      - indices: int128
 *      - swap method: exchange_underlying()
 *      Note: CurveWrappedAdapter has the same configuration,
 *      so _swap() implementation stays the same.
 */
abstract contract CurveMetaAdapter is CurveWrappedAdapter {
    // (MetaPoolToken, BasePool LP Token)
    // (MetaPoolToken, [BasePoolToken 1, BasePoolToken 2, BasePoolToken 3])
    //                      ^
    //                      |
    // index of first base pool token, always 1
    uint256 private constant FIRST_BASE_INDEX = 1;
    ICurvePool private immutable basePool;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported,
        address _basePool
    ) CurveWrappedAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {
        basePool = ICurvePool(_basePool);
        _setBasePoolTokensAllowance();
    }

    function _setPoolTokensAllowance() internal virtual override {
        _setInfiniteAllowance(IERC20(pool.coins(0)), address(pool));
    }

    function _setBasePoolTokensAllowance() internal {
        for (uint8 i = 0; true; i++) {
            try basePool.coins(i) returns (address _tokenAddress) {
                _setInfiniteAllowance(IERC20(_tokenAddress), address(pool));
            } catch {
                break;
            }
        }
    }

    function _loadToken(uint256 index) internal view virtual override returns (address) {
        if (index == 0) return pool.coins(0); // metapool token
        return basePool.coins(index - 1);
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
            return 0;
        }

        // quote for swaps from [base pool token] to [meta pool token] is
        // sometimes overly optimistic. Subtracting 1 bp should give
        // a more accurate lower bound for actual amount of tokens swapped
        if (_getIndex(_tokenIn) >= FIRST_BASE_INDEX && _getIndex(_tokenOut) < FIRST_BASE_INDEX) {
            _amountOut = (_amountOut * 9999) / 10000;
        }
    }
}
