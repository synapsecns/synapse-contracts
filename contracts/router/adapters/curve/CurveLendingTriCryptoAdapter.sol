// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveAbstractAdapter} from "./CurveAbstractAdapter.sol";

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract CurveLendingTriCryptoAdapter is CurveAbstractAdapter {
    /**
        @dev Lending TriCrypto Adapter is using uint256 for indexes
        and is using exchange_underlying() for swaps
     */

    uint256 private immutable numberStablecoins;

    mapping(address => uint256) public tokenIndex;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported,
        address _basePool
    ) CurveAbstractAdapter(_name, _swapGasEstimate, _pool, _directSwapSupported) {
        numberStablecoins = _getBasePoolSize(_basePool);
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

    function _addPoolToken(address _tokenAddress, uint8 _index) internal virtual override {
        isPoolToken[_tokenAddress] = true;
        tokenIndex[_tokenAddress] = _index;
    }

    function _getBasePoolSize(address _basePoolAddress) internal view returns (uint256 _numCoins) {
        ICurvePool _basePool = ICurvePool(_basePoolAddress);
        _numCoins = 0;
        for (;;) {
            try _basePool.coins(_numCoins) {
                _numCoins++;
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
        _amountOut = IERC20(_tokenOut).balanceOf(_to);
        pool.exchange_underlying(tokenIndex[_tokenIn], tokenIndex[_tokenOut], _amountIn, 0, _to);
        _amountOut = IERC20(_tokenOut).balanceOf(_to) - _amountOut;
    }

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual override returns (uint256 _amountOut) {
        pool.exchange_underlying(tokenIndex[_tokenIn], tokenIndex[_tokenOut], _amountIn, 0);
        // Imagine not returning amount of swapped tokens
        _amountOut = IERC20(_tokenOut).balanceOf(address(this));
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try pool.get_dy_underlying(tokenIndex[_tokenIn], tokenIndex[_tokenOut], _amountIn) returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            return 0;
        }

        // quote for swaps from [base pool token] to [meta pool token] is
        // sometimes overly optimistic. Subtracting 4 bp should give
        // a more accurate lower bound for actual amount of tokens swapped
        if (tokenIndex[_tokenIn] < numberStablecoins) {
            _amountOut = (_amountOut * 9996) / 10000;
        }
    }
}
