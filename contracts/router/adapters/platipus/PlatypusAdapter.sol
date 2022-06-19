// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../Adapter.sol";
import {AdapterInfinite} from "../tokens/AdapterInfinite.sol";
import {IPlatypusPool} from "./interfaces/IPlatypusPool.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract PlatypusAdapter is Adapter, AdapterInfinite {
    IPlatypusPool public immutable pool;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) Adapter(_name, _swapGasEstimate) {
        pool = IPlatypusPool(_pool);
        _setPoolTokens();
    }

    function _setPoolTokens() internal {
        address[] memory poolTokens = pool.getTokenAddresses();
        for (uint8 i = 0; i < poolTokens.length; ++i) {
            _setInfiniteAllowance(IERC20(poolTokens[i]), address(pool));
        }
    }

    // -- BASE ADAPTER FUNCTIONS

    function _depositAddress(address, address) internal view override returns (address) {
        return address(this);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        // solhint-disable not-rely-on-time
        (_amountOut, ) = pool.swap(_tokenIn, _tokenOut, _amountIn, 0, _to, block.timestamp);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (pool.paused()) {
            return 0;
        }
        try pool.quotePotentialSwap(_tokenIn, _tokenOut, _amountIn) returns (uint256 amountOut, uint256) {
            _amountOut = amountOut;
        } catch {
            return 0;
        }
    }
}
