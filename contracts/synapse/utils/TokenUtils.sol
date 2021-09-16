// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import {IMetaSwapDeposit} from '../interfaces/IMetaSwapDeposit.sol';

library TokenUtils {
    using SafeERC20 for IERC20;

    uint256 constant MAX_UINT256 = 2**256 - 1;

    /**
    * @dev approveMaxBridgeAllowance checks if the synapseBridge contract needs to have its pull allowance of
    * an ERC20 token increased. If it does, it increases that allowance to MAX_UINT256
    *
    * @param token ERC20 token to max out the allowance of
    * @param synapseBridge_ Address of the Synapse Bridge contract to approve increasing the pull allowance for.
    * @param amount Amount of token which needs to be pulled.
    */
    function approveMaxBridgeAllowance(
        IERC20 token,
        uint256 amount,
        address synapseBridge
    )
        internal
    {
        if (
            token.allowance(address(this), synapseBridge) < amount
        ) {
            token.safeApprove(synapseBridge, MAX_UINT256);
        }
    }

    /**
    * @dev Wraps SafeERC20.safeTransferFrom. Transfers `amount` of `token` from msg.sender to the calling contract.
    *
    * @param token ERC20 token to transfer from msg.sender to the calling contract.
    * @param amount Amount of token to transfer.
    */
    function safeTransferFromMsgSender(
        IERC20 token,
        uint256 amount
    )
        internal
    {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
    * @dev Wraps safeTransferFromMsgSender and approveMaxBridgeAllowance.
    *
    * @param token ERC20 token to transfer from msg.sender AND increase the bridge's allowance for
    * @param amount Amount of token to transfer
    * @param synapseBridge Address of the synapse bridge contract to approve token pulls for.
    */
    function safeTransferWithApprove(
        IERC20 token,
        uint256 amount,
        address synapseBridge
    )
        internal
    {
        safeTransferFromMsgSender(token, amount);
        approveMaxBridgeAllowance(token, amount, synapseBridge);
    }

    function swapWithApproval(
        address to,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        IERC20[] storage metaTokens,
        IMetaSwapDeposit metaSwap,
        address synapseBridge
    )
        internal
        returns (uint256)
    {
        safeTransferFromMsgSender(metaTokens[tokenIndexFrom], dx);
        // swap

        uint256 swappedAmount = metaSwap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        approveMaxBridgeAllowance(token, swappedAmount, synapseBridge);

        return swappedAmount;
    }
}
