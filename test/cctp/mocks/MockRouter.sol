// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseCCTP} from "../../../contracts/cctp/interfaces/ISynapseCCTP.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract MockRouter {
    using SafeERC20 for IERC20;

    address public synapseCCTP;

    constructor(address synapseCCTP_) {
        synapseCCTP = synapseCCTP_;
    }

    function sendCircleToken(
        address recipient,
        uint256 chainId,
        address burnToken,
        uint256 amount,
        uint32 requestVersion,
        bytes memory swapParams
    ) external {
        IERC20(burnToken).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(burnToken).approve(synapseCCTP, amount);
        ISynapseCCTP(synapseCCTP).sendCircleToken(recipient, chainId, burnToken, amount, requestVersion, swapParams);
    }
}
