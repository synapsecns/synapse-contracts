// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CurveAbstractAdapter} from "./CurveAbstractAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts-4.4.2/utils/math/SafeCast.sol";

contract CurveBaseAdapter is CurveAbstractAdapter {
    /**
        @dev Base Adapter is using int128 for indexes
        and is using exchange() for swaps
     */

    mapping(address => int128) public tokenIndex;

    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate,
        bool _directSwapSupported
    )
        CurveAbstractAdapter(
            _name,
            _pool,
            _swapGasEstimate,
            _directSwapSupported
        )
    {
        this;
    }

    function _addPoolToken(address _tokenAddress, uint8 _index)
        internal
        virtual
        override
    {
        isPoolToken[_tokenAddress] = true;
        tokenIndex[_tokenAddress] = SafeCast.toInt128(
            SafeCast.toInt256(_index)
        );
    }

    function _doDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override {
        pool.exchange(
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
        pool.exchange(
            tokenIndex[_tokenIn],
            tokenIndex[_tokenOut],
            _amountIn,
            0
        );
        // Imagine not returning amount of swapped tokens
        _amountOut = IERC20(_tokenOut).balanceOf(address(this));
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try
            pool.get_dy(tokenIndex[_tokenIn], tokenIndex[_tokenOut], _amountIn)
        returns (uint256 _amt) {
            // -1 to account for rounding errors.
            // This will underquote by 1 wei sometimes, but that's life
            _amountOut = _amt != 0 ? _amt - 1 : 0;
        } catch {
            _amountOut = 0;
        }
    }
}
