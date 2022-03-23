// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveBasePoolAdapter} from "./CurveBasePoolAdapter.sol";

contract CurveLendingPoolAdapter is CurveBasePoolAdapter {
    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate,
        bool _directSwapSupported
    )
        CurveBasePoolAdapter(
            _name,
            _pool,
            _swapGasEstimate,
            _directSwapSupported
        )
    {
        this;
    }

    function _setPoolTokens() internal virtual override {
        for (uint8 i = 0; true; i++) {
            try pool.underlying_coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, i);
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
    ) internal virtual override {
        pool.exchange_underlying(
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
