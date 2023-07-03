// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../interfaces/IPoolModule.sol";
import {ICurveV1Pool} from "../interfaces/curve/ICurveV1Pool.sol";

/// @notice PoolModule for Curve V1 pools
/// @dev Implements IPoolModule interface to be used with pools addeded to LinkedPool router
contract CurveV1Module is IPoolModule {
    using SafeERC20 for IERC20;

    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // TODO: any checks expected on inputs?
        int128 i = int128(uint128(tokenFrom.index));
        int128 j = int128(uint128(tokenTo.index));
        IERC20(tokenFrom.token).safeApprove(pool, amountIn);
        amountOut = ICurveV1Pool(pool).exchange(i, j, amountIn, 0);
    }

    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {
        // TODO: any checks expected on inputs?
        int128 i = int128(uint128(tokenFrom.index));
        int128 j = int128(uint128(tokenTo.index));
        amountOut = ICurveV1Pool(pool).get_dy(i, j, amountIn);
    }

    function getPoolTokens(address pool, uint256 tokensAmount) external view returns (address[] memory tokens) {
        require(tokensAmount == uint256(uint128(ICurveV1Pool(pool).N_COINS())), "tokensAmount != N_COINS"); // TODO(@chi): reverting ok in view?
        tokens = new address[](tokensAmount);
        for (uint256 i = 0; i < tokensAmount; i++) {
            tokens[i] = ICurveV1Pool(pool).coins(i);
        }
    }
}
