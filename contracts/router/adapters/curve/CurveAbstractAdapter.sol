// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../../Adapter.sol";
import {ICurvePool} from "../../interfaces/ICurvePool.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

abstract contract CurveAbstractAdapter is Adapter {
    ICurvePool public immutable pool;
    bool internal immutable directSwapSupported;

    mapping(address => bool) public isPoolToken;

    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate,
        bool _directSwapSupported
    ) Adapter(_name, _swapGasEstimate) {
        pool = ICurvePool(_pool);
        directSwapSupported = _directSwapSupported;
        _setPoolTokens();
    }

    function _setPoolTokens() internal virtual {
        for (uint8 i = 0; true; i++) {
            try pool.coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, i);
            } catch {
                break;
            }
        }
    }

    function _addPoolToken(address _tokenAddress, uint8 _index)
        internal
        virtual;

    function _approveIfNeeded(address _tokenIn, uint256 _amount)
        internal
        virtual
        override
    {
        _checkAllowance(IERC20(_tokenIn), _amount, address(pool));
    }

    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return isPoolToken[_tokenIn] && isPoolToken[_tokenOut];
    }


    function _depositAddress(address, address)
        internal
        view
        virtual
        override
        returns (address)
    {
        return address(this);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        if (directSwapSupported) {
            _amountOut = IERC20(_tokenOut).balanceOf(_to);
            _doDirectSwap(_amountIn, _tokenIn, _tokenOut, _to);
            _amountOut = IERC20(_tokenOut).balanceOf(_to) - _amountOut;
        } else {
            _amountOut = _doIndirectSwap(_amountIn, _tokenIn, _tokenOut);
            _returnTo(_tokenOut, _amountOut, _to);
        }
    }

    function _doDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual;

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual returns (uint256);
}
