// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

library UniversalTokenLib {
    using SafeERC20 for IERC20;

    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Transfers tokens to the given account. Reverts if transfer is not successful.
    /// @dev This might trigger fallback, if ETH is transferred to the contract.
    /// Make sure this can not lead to reentrancy attacks.
    function universalTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // Don't do anything, if need to send tokens to this address
        if (to == address(this)) return;
        if (token == ETH_ADDRESS) {
            /// @dev Note: this can potentially lead to executing code in `to`.
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = to.call{value: value}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, value);
        }
    }
}
