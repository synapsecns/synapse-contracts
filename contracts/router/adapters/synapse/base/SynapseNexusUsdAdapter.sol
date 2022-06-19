// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SynapseAdapter} from "../abstract/SynapseAdapter.sol";
import {AdapterFour} from "../../tokens/AdapterFour.sol";
import {AdapterBase} from "../../AdapterBase.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract SynapseNexusUsdAdapter is SynapseAdapter, AdapterFour {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SynapseAdapter(_name, _swapGasEstimate, _pool) {
        // add LP token as a "pool token"
        // This will enable stable <-> nUSD swap on Mainnet via adapter
        _setInfiniteAllowance(lpToken, address(pool));
    }

    function _loadToken(uint256 index) internal view virtual override(AdapterBase, SynapseAdapter) returns (address) {
        if (index == numTokens) return address(lpToken);
        return SynapseAdapter._loadToken(index);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        uint8 _indexIn = uint8(_getIndex(_tokenIn));
        uint8 _indexOut = uint8(_getIndex(_tokenOut));

        if (_indexIn == numTokens) {
            // remove liquidity
            // solhint-disable-next-line not-rely-on-time
            _amountOut = pool.removeLiquidityOneToken(_amountIn, _indexOut, 0, block.timestamp);
        } else if (_indexOut == numTokens) {
            // add liquidity
            uint256[] memory amounts = new uint256[](numTokens);
            amounts[_indexIn] = _amountIn;

            // solhint-disable-next-line not-rely-on-time
            _amountOut = pool.addLiquidity(amounts, 0, block.timestamp);
        } else {
            // swap tokens
            // solhint-disable-next-line not-rely-on-time
            _amountOut = pool.swap(_indexIn, _indexOut, _amountIn, 0, block.timestamp);
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
        uint8 _indexIn = uint8(_getIndex(_tokenIn));
        uint8 _indexOut = uint8(_getIndex(_tokenOut));

        if (_indexIn == numTokens) {
            // remove liquidity
            try pool.calculateRemoveLiquidityOneToken(_amountIn, _indexOut) returns (uint256 amountOut) {
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
            try pool.calculateSwap(_indexIn, _indexOut, _amountIn) returns (uint256 amountOut) {
                _amountOut = amountOut;
            } catch {
                return 0;
            }
        }
    }
}
