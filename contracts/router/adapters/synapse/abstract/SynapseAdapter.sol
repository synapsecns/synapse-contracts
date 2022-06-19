// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISynapse} from "../interfaces/ISynapse.sol";
import {Adapter} from "../../Adapter.sol";
import {SwapCalculator} from "../calc/SwapCalculator.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

abstract contract SynapseAdapter is SwapCalculator, Adapter {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SwapCalculator(ISynapse(_pool)) Adapter(_name, _swapGasEstimate) {} // solhint-disable-line no-empty-blocks

    function _addPoolToken(IERC20 token, uint256 index) internal virtual override {
        SwapCalculator._addPoolToken(token, index);
        _setInfiniteAllowance(token, address(pool));
    }

    function _castIndex(address _token) internal view returns (uint8) {
        return uint8(_getIndex(_token));
    }

    function _depositAddress(address, address) internal view override returns (address) {
        return address(this);
    }

    function _loadToken(uint256 index) internal view virtual override returns (address) {
        require(index < numTokens, "Index out of bounds");
        return address(poolTokens[index]);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        //solhint-disable-next-line not-rely-on-time
        _amountOut = pool.swap(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn, 0, block.timestamp);
        _returnTo(_tokenOut, _amountOut, _to);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (pool.paused()) return 0;
        try pool.calculateSwap(_castIndex(_tokenIn), _castIndex(_tokenOut), _amountIn) returns (uint256 amountOut) {
            _amountOut = amountOut;
        } catch {} // solhint-disable-line no-empty-blocks
    }
}
