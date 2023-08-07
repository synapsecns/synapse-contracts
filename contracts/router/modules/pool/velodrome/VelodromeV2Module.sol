// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";

import {IVelodromeV2Pool} from "../../../interfaces/velodrome/IVelodromeV2Pool.sol";
import {IVelodromeV2Router} from "../../../interfaces/velodrome/IVelodromeV2Router.sol";

import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

/// @notice PoolModule for Velodrome V2 pools
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract VelodromeV2Module is OnlyDelegateCall, IPoolModule {
    using SafeERC20 for IERC20;
    using UniversalTokenLib for address;

    IVelodromeV2Router public immutable router;

    constructor(address _router) {
        router = IVelodromeV2Router(_router);
    }

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        assertDelegateCall();
        address tokenIn = tokenFrom.token;
        tokenIn.universalApproveInfinity(address(router), amountIn);

        bool stable = IVelodromeV2Pool(pool).stable();
        address factory = IVelodromeV2Pool(pool).factory();
        IVelodromeV2Router.Route[] memory routes = new IVelodromeV2Router.Route[](1);
        routes[0] = IVelodromeV2Router.Route({
            from: tokenFrom.token,
            to: tokenTo.token,
            stable: stable,
            factory: factory
        });

        uint256[] memory amounts = new uint256[](2);
        amounts = router.swapExactTokensForTokens(amountIn, 0, routes, address(this), block.timestamp);
        amountOut = amounts[1];
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {
        (address token0, address token1) = IVelodromeV2Pool(pool).tokens();
        address tokenIn = tokenFrom.token;
        address tokenOut = tokenTo.token;
        require(
            (tokenIn == token0 && tokenOut == token1) || (tokenIn == token1 && tokenOut == token0),
            "tokens not in pool"
        );
        amountOut = IVelodromeV2Pool(pool).getAmountOut(amountIn, tokenIn);
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        (address token0, address token1) = IVelodromeV2Pool(pool).tokens();
        tokens = new address[](2);
        tokens[0] = token0;
        tokens[1] = token1;
    }
}
