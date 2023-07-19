// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {IGMXV1Router} from "../../../interfaces/gmx/IGMXV1Router.sol";
import {IGMXV1Vault} from "../../../interfaces/gmx/IGMXV1Vault.sol";

import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

/// @notice PoolModule for GMX V1 pools
/// @dev Implements IPoolModule interface to be used with pools addeded to LinkedPool router
contract GMXV1Module is OnlyDelegateCall, IPoolModule {
    using SafeERC20 for IERC20;

    IGMXV1Router public immutable router;
    IGMXV1Vault public immutable vault;

    constructor(address _router) {
        router = IGMXV1Router(_router);
        vault = IGMXV1Vault(router.vault());
    }

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        assertDelegateCall();
        require(pool == address(vault), "pool != vault");
        address tokenIn = tokenFrom.token;
        IERC20(tokenIn).safeApprove(address(router), amountIn);

        address tokenOut = tokenTo.token;
        uint256 balanceTo = IERC20(tokenOut).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = tokenFrom.token;
        path[1] = tokenTo.token;
        router.swap(path, amountIn, 0, address(this));

        amountOut = IERC20(tokenOut).balanceOf(address(this)) - balanceTo;
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {
        require(pool == address(vault), "pool != vault");
        // TODO: simulate like balancer module; would need to remove view
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        require(pool == address(vault), "pool != vault");
        uint256 numCoins = vault.whitelistedTokenCount();

        tokens = new address[](numCoins);
        for (uint256 i = 0; i < numCoins; i++) {
            tokens[i] = vault.allWhitelistedTokens(i);
        }
    }
}
