// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISynapse} from "../../interfaces/ISynapse.sol";
import {IAdapter} from "../../interfaces/IAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import "hardhat/console.sol";

contract TestAdapterSwap {
    using SafeERC20 for IERC20;

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
        IERC20(_tokenIn).safeTransferFrom(
            msg.sender,
            depositAddress,
            _amountIn
        );

        uint256 amountQuoted = adapter.query(_amountIn, _tokenIn, _tokenOut);

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
}
