// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../../Adapter.sol";

abstract contract WrapperAdapter is Adapter {
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

    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return
            (_tokenIn == tokenNative || _tokenIn == tokenWrapped) &&
            (_tokenOut == tokenNative || _tokenOut == tokenWrapped);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        // both tokens are checked to be either A or B
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
        // both tokens are checked to be either A or B
        // they are also checked to be different
        if (_tokenIn == tokenNative) {
            _amountOut = _queryNativeToWrapped(_amountIn);
        } else {
            _amountOut = _queryWrappedToNative(_amountIn);
        }
    }

    // -- ABSTRACT FUNCTIONS --

    function _isPaused() internal view virtual returns (bool);

    function _swapNativeToWrapped(uint256 _amountIn, address _to)
        internal
        virtual
        returns (uint256);

    function _swapWrappedToNative(uint256 _amountIn, address _to)
        internal
        virtual
        returns (uint256);

    function _queryNativeToWrapped(uint256 _amountIn)
        internal
        view
        virtual
        returns (uint256);

    function _queryWrappedToNative(uint256 _amountIn)
        internal
        view
        virtual
        returns (uint256);
}
