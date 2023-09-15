// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract MockBridge {
    using SafeERC20 for IERC20;

    event Deposit(address recipient, uint256 chainId, address token, uint256 amount, bytes params);

    function deposit(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        bytes memory params
    ) external payable {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(to, chainId, token, amount, params);
    }
}
