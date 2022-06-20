// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../../Adapter.sol";
import {AdapterIndexed} from "../../tokens/AdapterIndexed.sol";

import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

/// @dev Base contract for all Curve adapters.
abstract contract CurveAdapter is Adapter, AdapterIndexed {
    ICurvePool public immutable pool;
    bool internal immutable directSwapSupported;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        bool _directSwapSupported
    ) Adapter(_name, _swapGasEstimate) {
        pool = ICurvePool(_pool);
        directSwapSupported = _directSwapSupported;
        _setPoolTokensAllowance();
    }

    function _setPoolTokensAllowance() internal virtual {
        for (uint256 i = 0; true; i++) {
            try pool.coins(i) returns (address _tokenAddress) {
                _setInfiniteAllowance(IERC20(_tokenAddress), address(pool));
            } catch {
                break;
            }
        }
    }

    function _depositAddress(address, address) internal view virtual override returns (address) {
        return address(this);
    }

    function _loadToken(uint256 index) internal view virtual override returns (address) {
        return pool.coins(index);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        if (directSwapSupported) {
            _amountOut = _doDirectSwap(_amountIn, _tokenIn, _tokenOut, _to);
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
    ) internal virtual returns (uint256);

    function _doIndirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal virtual returns (uint256);
}
