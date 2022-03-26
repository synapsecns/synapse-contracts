// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISynapse} from "../interfaces/ISynapse.sol";
import {Adapter} from "../../Adapter.sol";
import {SwapCalculator} from "../../helper/SwapCalculator.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

//solhint-disable not-rely-on-time

contract SynapseBaseAdapter is SwapCalculator, Adapter {
    mapping(address => bool) public isPoolToken;
    mapping(address => uint256) public tokenIndex;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SwapCalculator(ISynapse(_pool)) Adapter(_name, _swapGasEstimate) {
        this;
    }

    function _addPoolToken(IERC20 token, uint256 index)
        internal
        virtual
        override
    {
        SwapCalculator._addPoolToken(token, index);
        _registerPoolToken(token, index);
    }

    function _registerPoolToken(IERC20 token, uint256 index) internal {
        isPoolToken[address(token)] = true;
        tokenIndex[address(token)] = index;
        _setInfiniteAllowance(token, address(pool));
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
        _amountOut = pool.swap(
            uint8(tokenIndex[_tokenIn]),
            uint8(tokenIndex[_tokenOut]),
            _amountIn,
            0,
            block.timestamp
        );

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
        try
            pool.calculateSwap(
                uint8(tokenIndex[_tokenIn]),
                uint8(tokenIndex[_tokenOut]),
                _amountIn
            )
        returns (uint256 amountOut) {
            _amountOut = amountOut;
        } catch {
            return 0;
        }
    }
}
