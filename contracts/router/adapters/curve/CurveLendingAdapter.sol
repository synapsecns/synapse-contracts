// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveBaseAdapter} from "./CurveBaseAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

contract CurveLendingAdapter is CurveBaseAdapter {
    /**
        @dev Base Adapter is using int128 for indexes
        and is using exchange_underlying() for swaps
     */

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) CurveBaseAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {
        this;
    }

    function _setPoolTokens() internal virtual override {
        for (uint8 i = 0; true; i++) {
            try pool.underlying_coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, i);
                _setInfiniteAllowance(IERC20(_tokenAddress), address(pool));
            } catch {
                break;
            }
        }
    }

    function _doDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = pool.exchange_underlying(
            tokenIndex[_tokenIn],
            tokenIndex[_tokenOut],
            _amountIn,
            0,
            _to
        );
    }

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = pool.exchange_underlying(
            tokenIndex[_tokenIn],
            tokenIndex[_tokenOut],
            _amountIn,
            0
        );
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try
            pool.get_dy_underlying(
                tokenIndex[_tokenIn],
                tokenIndex[_tokenOut],
                _amountIn
            )
        returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            _amountOut = 0;
        }
    }
}
