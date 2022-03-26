// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseBaseAdapter} from "./SynapseBaseAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

//solhint-disable not-rely-on-time

contract SynapseBaseMainnetAdapter is SynapseBaseAdapter {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SynapseBaseAdapter(_name, _swapGasEstimate, _pool) {
        // add LP token as a "pool token"
        // This will enable stable <-> nUSD swap on Mainnet via adapter
        _registerPoolToken(lpToken, numTokens);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        uint8 _indexIn = uint8(tokenIndex[_tokenIn]);
        uint8 _indexOut = uint8(tokenIndex[_tokenOut]);

        if (_indexIn == numTokens) {
            // remove liquidity
            _amountOut = pool.removeLiquidityOneToken(
                _amountIn,
                _indexOut,
                0,
                block.timestamp
            );
        } else if (_indexOut == numTokens) {
            // add liquidity
            uint256[] memory amounts = new uint256[](numTokens);
            amounts[_indexIn] = _amountIn;

            _amountOut = pool.addLiquidity(amounts, 0, block.timestamp);
        } else {
            // swap tokens
            _amountOut = pool.swap(
                _indexIn,
                _indexOut,
                _amountIn,
                0,
                block.timestamp
            );
        }
        _returnTo(_tokenOut, _amountOut, _to);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (pool.paused()) {
            return 0;
        }
        uint8 _indexIn = uint8(tokenIndex[_tokenIn]);
        uint8 _indexOut = uint8(tokenIndex[_tokenOut]);

        if (_indexIn == numTokens) {
            // remove liquidity
            try
                pool.calculateRemoveLiquidityOneToken(_amountIn, _indexOut)
            returns (uint256 amountOut) {
                _amountOut = amountOut;
            } catch {
                return 0;
            }
        } else if (_indexOut == numTokens) {
            // add liquidity
            uint256[] memory _amounts = new uint256[](numTokens);
            _amounts[_indexIn] = _amountIn;

            _amountOut = calculateAddLiquidity(_amounts);
        } else {
            // swap tokens
            try pool.calculateSwap(_indexIn, _indexOut, _amountIn) returns (
                uint256 amountOut
            ) {
                _amountOut = amountOut;
            } catch {
                return 0;
            }
        }
    }
}
