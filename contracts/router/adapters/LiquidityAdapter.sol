// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

import {ILiquidityAdapter} from "../interfaces/ILiquidityAdapter.sol";

abstract contract LiquidityAdapter is ILiquidityAdapter {
	using SafeERC20 for IERC20;

	function _returnUnwrappedToken(
        address to,
        IERC20 token,
        uint256 amount,
        bool unwrapGas,
        IWETH9 wgas
    ) internal virtual {
        if (unwrapGas && address(token) == address(wgas)) {
            wgas.withdraw(amount);
            (bool success, ) = to.call{value: amount}("");
            require(success, "GAS transfer failed");
        } else {
            token.safeTransfer(to, amount);
        }
    }
}