// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultAdapter} from "./adapters/DefaultAdapter.sol";
import {MsgValueIncorrect, TokenNotETH} from "./libs/Errors.sol";
import {UniversalTokenLib} from "./libs/UniversalToken.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

/// @title DefaultRouter
/// @notice Base contract for all Synapse Routers, that is able to natively work with Default Pools
/// due to the fact that it inherits from DefaultAdapter.
abstract contract DefaultRouter is DefaultAdapter {
    using SafeERC20 for IERC20;
    using UniversalTokenLib for address;

    /// @dev Pulls a requested token from the user to the requested recipient.
    /// Or, if msg.value was provided, check that ETH_ADDRESS was used and msg.value is correct.
    function _pullToken(
        address recipient,
        address token,
        uint256 amount
    ) internal returns (uint256 amountPulled) {
        if (msg.value == 0) {
            token.assertIsContract();
            // Record token balance before transfer
            amountPulled = IERC20(token).balanceOf(recipient);
            // Token needs to be pulled only if msg.value is zero
            // This way user can specify WETH as the origin asset
            IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
            // Use the difference between the recorded balance and the current balance as the amountPulled
            amountPulled = IERC20(token).balanceOf(recipient) - amountPulled;
        } else {
            // Otherwise, we need to check that ETH was specified
            if (token != UniversalTokenLib.ETH_ADDRESS) revert TokenNotETH();
            // And that amount matches msg.value
            if (amount != msg.value) revert MsgValueIncorrect();
            // We will forward msg.value in the external call later, if recipient is not this contract
            amountPulled = msg.value;
        }
    }
}
