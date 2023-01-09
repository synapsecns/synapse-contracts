// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./BridgeStructs.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * Library to unify handling of ETH/WETH and ERC20 tokens.
 */
library UniversalToken {
    using SafeERC20 for IERC20;

    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant MAX_UINT = type(uint256).max;

    /// @notice Returns token balance for the given account.
    function universalBalanceOf(address token, address account) internal view returns (uint256) {
        if (token == ETH_ADDRESS) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    /// @notice Compares two tokens. ETH_ADDRESS and WETH are deemed equal.
    function universalEquals(address token, PoolToken memory poolToken) internal pure returns (bool) {
        if (token == ETH_ADDRESS) {
            return poolToken.isWeth;
        } else {
            return token == poolToken.token;
        }
    }

    function universalApproveInfinity(address token, address spender) internal {
        // ETH Chad doesn't require your approval
        if (token == ETH_ADDRESS) return;
        // No need to approve own tokens
        if (spender == address(this)) return;
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        // Set allowance to MAX_UINT if needed
        if (allowance != MAX_UINT) {
            // if allowance is neither zero nor infinity, reset if first
            if (allowance != 0) {
                IERC20(token).safeApprove(spender, 0);
            }
            IERC20(token).safeApprove(spender, MAX_UINT);
        }
    }

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
