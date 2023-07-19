// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {ICurveV1Pool} from "../../../interfaces/curve/ICurveV1Pool.sol";

import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

/// @notice PoolModule for Curve V1 pools
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract CurveV1Module is OnlyDelegateCall, IPoolModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        assertDelegateCall();
        int128 i = int128(uint128(tokenFrom.index));
        int128 j = int128(uint128(tokenTo.index));
        IERC20(tokenFrom.token).safeApprove(pool, amountIn);
        amountOut = ICurveV1Pool(pool).exchange(i, j, amountIn, 0);
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {
        int128 i = int128(uint128(tokenFrom.index));
        int128 j = int128(uint128(tokenTo.index));
        amountOut = ICurveV1Pool(pool).get_dy(i, j, amountIn);
    }

    /// @dev same logic as LinkedPool.sol::_getPoolTokens
    function _numTokens(address pool) public view returns (uint256 numTokens) {
        while (true) {
            try ICurveV1Pool(pool).coins(numTokens) returns (address) {
                unchecked {
                    ++numTokens;
                }
            } catch {
                break;
            }
        }
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        uint256 numTokens = _numTokens(pool);
        tokens = new address[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            tokens[i] = ICurveV1Pool(pool).coins(i);
        }
    }
}
