// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UniswapV2Adapter} from "./UniswapV2Adapter.sol";
import {IMintBurnWrapper} from "../../../vault/interfaces/IMintBurnWrapper.sol";

contract UniswapV2MintBurnAdapter is UniswapV2Adapter {
    IMintBurnWrapper public immutable wrapper;
    address public immutable tokenNative;

    constructor(
        string memory _name,
        address _uniswapV2FactoryAddress,
        uint256 _swapGasEstimate,
        uint256 _fee,
        IMintBurnWrapper _wrapper
    )
        UniswapV2Adapter(
            _name,
            _uniswapV2FactoryAddress,
            _swapGasEstimate,
            _fee
        )
    {
        wrapper = _wrapper;
        tokenNative = _wrapper.tokenNative();
    }

    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (_tokenIn == tokenNative) {
            return UniswapV2Adapter._checkTokens(tokenNative, _tokenOut);
        } else if (_tokenOut == tokenNative) {
            return UniswapV2Adapter._checkTokens(_tokenIn, tokenNative);
        } else {
            return false;
        }
    }

    function _depositAddress(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (address)
    {
        if (_tokenIn == tokenNative) {
            return UniswapV2Adapter._depositAddress(tokenNative, _tokenOut);
        } else if (_tokenOut == tokenNative) {
            return UniswapV2Adapter._depositAddress(_tokenIn, tokenNative);
        } else {
            return address(0);
        }
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        if (_tokenIn == tokenNative) {
            _amountOut = UniswapV2Adapter._swap(
                _amountIn,
                tokenNative,
                _tokenOut,
                _to
            );
        } else if (_tokenOut == tokenNative) {
            _amountOut = UniswapV2Adapter._swap(
                _amountIn,
                _tokenIn,
                tokenNative,
                _to
            );
        } else {
            return 0;
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (_tokenIn == tokenNative) {
            _amountOut = UniswapV2Adapter._query(
                _amountIn,
                tokenNative,
                _tokenOut
            );
        } else if (_tokenOut == tokenNative) {
            _amountOut = UniswapV2Adapter._query(
                _amountIn,
                _tokenIn,
                tokenNative
            );
        } else {
            return 0;
        }
    }
}
