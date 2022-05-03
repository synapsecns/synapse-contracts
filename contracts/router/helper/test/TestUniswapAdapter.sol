// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "../../interfaces/IAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import "hardhat/console.sol";

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract TestUniswapAdapter {
    using SafeERC20 for IERC20;

    IUniswapV2Router private router;

    constructor(address _routerAddress) {
        router = IUniswapV2Router(_routerAddress);
    }

    function testSwap(
        address _adapterAddress,
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        bool _checkUnderQuoting,
        uint256 _iteration
    ) external {
        IAdapter adapter = IAdapter(_adapterAddress);

        address depositAddress = adapter.depositAddress(_tokenIn, _tokenOut);
        if (depositAddress == address(0)) {
            console.log("Swap # %s", _iteration);
            console.log("Swap not found for %s %s", _tokenIn, _tokenOut);
            revert("Swap not found");
        }

        IERC20(_tokenIn).safeTransferFrom(
            msg.sender,
            depositAddress,
            _amountIn
        );

        uint256 amountQuoted = adapter.query(_amountIn, _tokenIn, _tokenOut);

        checkAmountQuoted(
            _amountIn,
            _tokenIn,
            _tokenOut,
            amountQuoted,
            _iteration
        );

        uint256 amountSwapped = adapter.swap(
            _amountIn,
            _tokenIn,
            _tokenOut,
            address(this)
        );
        uint256 amountReceived = IERC20(_tokenOut).balanceOf(address(this));

        if (amountSwapped != amountReceived) {
            console.log("Swap # %s", _iteration);
            console.log(
                "swap: Expected %s, got %s",
                amountSwapped,
                amountReceived
            );
            revert("swap() failed to return amount of tokens");
        }

        if (
            amountQuoted > amountReceived ||
            (amountQuoted < amountReceived && _checkUnderQuoting)
        ) {
            console.log("Swap # %s", _iteration);
            if (amountQuoted > amountReceived) {
                console.log(
                    "swap: (over)Quoted %s, got %s (diff: %s)",
                    amountQuoted,
                    amountReceived,
                    amountQuoted - amountReceived
                );
            } else {
                console.log(
                    "swap: (under)Quoted %s, got %s (diff: %s)",
                    amountQuoted,
                    amountReceived,
                    amountReceived - amountQuoted
                );
            }
            revert("query() failed to provide a good quote");
        }

        IERC20(_tokenOut).safeTransfer(msg.sender, amountReceived);
    }

    function checkAmountQuoted(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountQuoted,
        uint256 _iteration
    ) internal view {
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
        uint256[] memory _amountsOut = router.getAmountsOut(_amountIn, path);
        uint256 _amountOut = _amountsOut[1];
        if (_amountOut != _amountQuoted) {
            console.log("Swap # %s", _iteration);
            if (_amountQuoted > _amountOut) {
                console.log(
                    "swap: (over)Quoted %s, actually %s (diff: %s)",
                    _amountQuoted,
                    _amountOut,
                    _amountQuoted - _amountOut
                );
            } else {
                console.log(
                    "swap: (under)Quoted %s, actually %s (diff: %s)",
                    _amountQuoted,
                    _amountOut,
                    _amountOut - _amountQuoted
                );
            }
            revert("query() failed to provide a good quote");
        }
    }
}
