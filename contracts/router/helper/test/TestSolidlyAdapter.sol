// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "../../interfaces/IAdapter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {ISolidlyPair} from "../../adapters/interfaces/ISolidlyPair.sol";

import "hardhat/console.sol";

// solhint-disable reason-string

interface ISolidlyRouter {
    struct Route {
        address from;
        address to;
        bool stable;
    }

    function getAmountsOut(uint256 amountIn, Route[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract TestSolidlyAdapter {
    using SafeERC20 for IERC20;

    ISolidlyRouter private immutable router;
    bool private immutable stable;

    constructor(address _routerAddress, bool _stable) {
        router = ISolidlyRouter(_routerAddress);
        stable = _stable;
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

        (uint256 reserve0, uint256 reserve1, ) = ISolidlyPair(depositAddress)
            .getReserves();

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

        uint256 amountSwapped = 0;

        try
            adapter.swap(_amountIn, _tokenIn, _tokenOut, address(this))
        returns (uint256 _amountSwapped) {
            amountSwapped = _amountSwapped;
        } catch {
            console.log("Swap failed: # %s", _iteration);
            console.log("%s -> %s", _tokenIn, _tokenOut);
            console.log("AmountIn: %s", _amountIn);
            console.log("Quote: %s", amountQuoted);
            console.log("%s %s", reserve0, reserve1);
            revert("swap() failed");
        }
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

        // console.log("%s -> %s", _tokenIn, _tokenOut);
        // console.log("AmountIn: %s", _amountIn);
        // console.log("Quote: %s", amountQuoted);
        IERC20(_tokenOut).safeTransfer(msg.sender, amountReceived);
    }

    function checkAmountQuoted(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountQuoted,
        uint256 _iteration
    ) internal view {
        ISolidlyRouter.Route[] memory path = new ISolidlyRouter.Route[](1);
        path[0] = ISolidlyRouter.Route(_tokenIn, _tokenOut, stable);
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
