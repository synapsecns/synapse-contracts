// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../Adapter.sol";
import {AdapterFinite} from "../tokens/AdapterFinite.sol";

abstract contract WrapperAdapter is Adapter, AdapterFinite {
    address public immutable tokenNative;
    address public immutable tokenWrapped;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _tokenNative,
        address _tokenWrapped
    ) Adapter(_name, _swapGasEstimate) {
        tokenNative = _tokenNative;
        tokenWrapped = _tokenWrapped;
    }

    function _checkToken(address token) internal view virtual override returns (bool) {
        return token == tokenNative || token == tokenWrapped;
    }

    function _getIndex(address _token) internal view virtual override returns (uint256) {
        if (_token == tokenNative) return 0;
        if (_token == tokenWrapped) return 1;
        revert("Unknown token");
    }

    function _getToken(uint256 index) internal view virtual override returns (address) {
        if (index == 0) return tokenNative;
        if (index == 1) return tokenWrapped;
        revert("Index out of bounds");
    }

    function _loadToken(uint256 index) internal view virtual override returns (address) {
        return _getToken(index);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        // both tokens are checked to be either native or wrapped at this point
        // they are also checked to be different
        if (_tokenIn == tokenNative) {
            _amountOut = _swapNativeToWrapped(_amountIn, _to);
        } else {
            _amountOut = _swapWrappedToNative(_amountIn, _to);
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address
    ) internal view virtual override returns (uint256 _amountOut) {
        if (_isPaused()) {
            return 0;
        }
        // both tokens are checked to be either native or wrapped at this point
        // they are also checked to be different
        if (_tokenIn == tokenNative) {
            _amountOut = _queryNativeToWrapped(_amountIn);
        } else {
            _amountOut = _queryWrappedToNative(_amountIn);
        }
    }

    // -- ABSTRACT FUNCTIONS --

    function _isPaused() internal view virtual returns (bool);

    function _swapNativeToWrapped(uint256 _amountIn, address _to) internal virtual returns (uint256);

    function _swapWrappedToNative(uint256 _amountIn, address _to) internal virtual returns (uint256);

    function _queryNativeToWrapped(uint256 _amountIn) internal view virtual returns (uint256);

    function _queryWrappedToNative(uint256 _amountIn) internal view virtual returns (uint256);
}
