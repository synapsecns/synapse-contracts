// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import {IWETH9} from "../interfaces/IWETH9.sol";

library WETHUtils {
    function transferWETH(
        address payable WETH_ADDRESS,
        address to,
        uint256 amount
    )
        internal
    {
        IWETH9(WETH_ADDRESS).withdraw(amount);

        (bool success,) = payable(to).call{value: amount}("");

        require(
            success,
            "ETH transfer failed"
        );
    }

    function validWETHAddress(
        address payable WETH_ADDRESS,
        address token
    )
        internal
        view
        returns (bool)
    {
        return token == WETH_ADDRESS && WETH_ADDRESS != address(0);
    }
}
