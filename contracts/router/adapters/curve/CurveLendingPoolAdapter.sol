// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveBasePoolAdapter} from "./CurveBasePoolAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

contract CurveLendingPoolAdapter is CurveBasePoolAdapter {
    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate
    ) CurveBasePoolAdapter(_name, _pool, _swapGasEstimate) {
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

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        require(_amountIn != 0, "Curve: Insufficient input amount");
        require(
            isPoolToken[_tokenIn] && isPoolToken[_tokenOut],
            "Curve: unknown tokens"
        );
        _amountOut = pool.exchange_underlying(
            tokenIndex[_tokenIn],
            tokenIndex[_tokenOut],
            _amountIn,
            0
        );
        _returnTo(_tokenOut, _amountOut, _to);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256) {
        if (
            _amountIn == 0 || !isPoolToken[_tokenIn] || !isPoolToken[_tokenOut]
        ) {
            return 0;
        }
        // -1 to account for rounding errors.
        // This will underquote by 1 wei sometimes, but that's life
        return
            pool.get_dy_underlying(
                tokenIndex[_tokenIn],
                tokenIndex[_tokenOut],
                _amountIn
            ) - 1;
    }
}
