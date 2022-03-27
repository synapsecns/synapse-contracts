// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WrapperAdapter} from "./WrapperAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface IGmx {
    function burn(address _account, uint256 _amount) external;

    function balanceOf(address account) external view returns (uint256);

    function mint(address _account, uint256 _amount) external;
}

interface ISynapseERC20 {
    function burn(uint256 _amount) external;

    function mint(address _account, uint256 _amount) external;
}

contract GmxWrapperAdapter is WrapperAdapter {
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _gmx,
        address _synGmx
    ) WrapperAdapter(_name, _swapGasEstimate, _gmx, _synGmx) {
        this;
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
        return false;
    }

    function _swapNativeToWrapped(uint256 _amountIn, address _to)
        internal
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = _amountIn;
        uint256 balanceBefore = IGmx(tokenNative).balanceOf(address(this));

        IGmx(tokenNative).burn(address(this), _amountIn);
        ISynapseERC20(tokenWrapped).mint(_to, _amountIn);

        uint256 balanceAfter = IGmx(tokenNative).balanceOf(address(this));
        require(
            balanceBefore == balanceAfter + _amountIn,
            "Burn is incomplete"
        );
    }

    function _swapWrappedToNative(uint256 _amountIn, address _to)
        internal
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = _amountIn;
        uint256 balanceBefore = IGmx(tokenNative).balanceOf(_to);

        ISynapseERC20(tokenNative).burn(_amountIn);
        IGmx(tokenNative).mint(_to, _amountIn);

        uint256 balanceAfter = IGmx(tokenNative).balanceOf(_to);
        require(
            balanceBefore + _amountIn == balanceAfter,
            "Mint is incomplete"
        );
    }

    function _queryNativeToWrapped(uint256 _amountIn)
        internal
        view
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = _amountIn;
    }

    function _queryWrappedToNative(uint256 _amountIn)
        internal
        view
        virtual
        override
        returns (uint256 _amountOut)
    {
        _amountOut = _amountIn;
    }
}
