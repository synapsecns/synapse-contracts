// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveLendingPoolAdapter} from "./CurveLendingPoolAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {ICurvePool} from "../../interfaces/ICurvePool.sol";

import {SafeCast} from "@openzeppelin/contracts-4.4.2/utils/math/SafeCast.sol";

contract CurveMetaPoolAdapter is CurveLendingPoolAdapter {
    // (MetaPoolToken, BasePool LP Token)
    // (MetaPoolToken, [BasePoolToken 1, BasePoolToken 2, BasePoolToken 3])
    //                      ^
    //                      |
    // index of first base pool token, most of the time = 1
    int128 private firstBaseIndex;

    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate,
        address _basePool
    ) CurveLendingPoolAdapter(_name, _pool, _swapGasEstimate) {
        _addBasePoolTokens(_basePool);
    }

    function _setPoolTokens() internal virtual override {
        address _lastToken;
        int128 _numTokens = 0;
        for (uint8 i = 0; true; i++) {
            try pool.coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, i);
                _lastToken = _tokenAddress;
                _numTokens++;
            } catch {
                break;
            }
        }
        // remove last token aka LP token for base pool
        isPoolToken[_lastToken] = false;
        tokenIndex[_lastToken] = 0;
        firstBaseIndex = _numTokens - 1;
    }

    function _addBasePoolTokens(address _basePoolAddress) internal {
        uint8 _numTokens = SafeCast.toUint8(SafeCast.toUint256(firstBaseIndex));
        ICurvePool _basePool = ICurvePool(_basePoolAddress);
        for (uint8 i = 0; true; i++) {
            try _basePool.coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, _numTokens);
                _numTokens++;
            } catch {
                break;
            }
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (
            _amountIn == 0 || !isPoolToken[_tokenIn] || !isPoolToken[_tokenOut]
        ) {
            return 0;
        }
        // -1 to account for rounding errors.
        // This will underquote by 1 wei sometimes, but that's life
        _amountOut =
            pool.get_dy_underlying(
                tokenIndex[_tokenIn],
                tokenIndex[_tokenOut],
                _amountIn
            ) -
            1;

        // quote for swaps from [base pool token] to [meta pool token] is
        // sometimes overly optimistic. Subtracting 1 bp should give
        // a more accurate lower bound for actual amount of tokens swapped
        if (
            tokenIndex[_tokenIn] >= firstBaseIndex &&
            tokenIndex[_tokenOut] < firstBaseIndex
        ) {
            _amountOut = (_amountOut * 9999) / 10000;
        }
    }
}
