// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WrapperAdapter} from "./WrapperAdapter.sol";

import {IFrax} from "../interfaces/IFrax.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

contract FraxAdapter is WrapperAdapter {
    // Constant for FRAX price precision
    uint256 private constant PRICE_PRECISION = 1e6;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _frax,
        address _synFrax
    ) WrapperAdapter(_name, _swapGasEstimate, _frax, _synFrax) {
        _setInfiniteAllowance(IERC20(_synFrax), _frax);

        // Chad (FRAX) doesn't need your approval to burn FRAX
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

    function _isPaused() internal view virtual override returns (bool) {
        return
            IFrax(tokenNative).exchangesPaused() ||
            !IFrax(tokenNative).canSwap(tokenWrapped);
    }

    function _swapNativeToWrapped(uint256 _amountIn, address _to)
        internal
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = IFrax(tokenNative).exchangeCanonicalForOld(
            tokenWrapped,
            _amountIn
        );
        _returnTo(tokenWrapped, _amountOut, _to);
    }

    function _swapWrappedToNative(uint256 _amountIn, address _to)
        internal
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = IFrax(tokenNative).exchangeOldForCanonical(
            tokenWrapped,
            _amountIn
        );
        _returnTo(tokenNative, _amountOut, _to);
    }

    function _queryNativeToWrapped(uint256 _amountIn)
        internal
        view
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = _amountIn;
        if (!IFrax(tokenNative).fee_exempt_list(address(this))) {
            _amountOut -=
                (_amountOut * IFrax(tokenNative).swap_fees(tokenWrapped, 1)) /
                PRICE_PRECISION;
        }
        if (IERC20(tokenWrapped).balanceOf(tokenNative) < _amountOut) {
            // if FRAX contract doesn't have enough synFRAX, swap will fail
            _amountOut = 0;
        }
    }

    function _queryWrappedToNative(uint256 _amountIn)
        internal
        view
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = _amountIn;
        if (!IFrax(tokenNative).fee_exempt_list(address(this))) {
            _amountOut -=
                (_amountOut * IFrax(tokenNative).swap_fees(tokenWrapped, 0)) /
                PRICE_PRECISION;
        }
        uint256 _newTotalSupply = IERC20(tokenNative).totalSupply() +
            _amountOut;
        if (IFrax(tokenNative).mint_cap() < _newTotalSupply) {
            // Can't mint more FRAX than mint cap specifies, swap will fail
            _amountOut = 0;
        }
    }
}
