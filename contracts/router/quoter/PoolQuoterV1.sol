// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../interfaces/IDefaultPoolCalc.sol";
import {IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";
import {ISwapQuoterV1, PoolToken} from "../interfaces/ISwapQuoterV1.sol";

/// @notice Stateless abstraction to calculate exact quotes for any DefaultPool instances.
abstract contract PoolQuoterV1 is ISwapQuoterV1 {
    IDefaultPoolCalc internal immutable _defaultPoolCalc;
    address internal immutable _weth;

    constructor(address defaultPoolCalc, address weth) {
        _defaultPoolCalc = IDefaultPoolCalc(defaultPoolCalc);
        _weth = weth;
    }

    // ═══════════════════════════════════════════ SPECIFIC POOL QUOTES ════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256 amountOut) {
        // Forward the only getter that is not properly implemented in the StableSwap contract (DefaultPool).
        return _defaultPoolCalc.calculateAddLiquidity(pool, amounts);
    }

    /// @inheritdoc ISwapQuoterV1
    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        return IDefaultExtendedPool(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    /// @inheritdoc ISwapQuoterV1
    function calculateRemoveLiquidity(address pool, uint256 amount)
        external
        view
        returns (uint256[] memory amountsOut)
    {
        return IDefaultExtendedPool(pool).calculateRemoveLiquidity(amount);
    }

    /// @inheritdoc ISwapQuoterV1
    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 amountOut) {
        return IDefaultExtendedPool(pool).calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
    }

    // ══════════════════════════════════════════════ POOL GETTERS V1 ══════════════════════════════════════════════════

    /// @inheritdoc ISwapQuoterV1
    function poolInfo(address pool) external view returns (uint256 numTokens, address lpToken) {
        numTokens = _numTokens(pool);
        lpToken = _lpToken(pool);
    }

    /// @inheritdoc ISwapQuoterV1
    function poolTokens(address pool) external view returns (PoolToken[] memory tokens) {
        tokens = _getPoolTokens(pool);
    }

    // ══════════════════════════════════════════════ POOL INSPECTION ══════════════════════════════════════════════════

    /// @dev Returns the LP token address for the given pool, if it exists. Otherwise, returns address(0).
    function _lpToken(address pool) internal view returns (address) {
        // Try getting the LP token address from the pool.
        try IDefaultExtendedPool(pool).swapStorage() returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address lpToken
        ) {
            return lpToken;
        } catch {
            // Return address(0) if the pool doesn't have an LP token.
            return address(0);
        }
    }

    /// @dev Returns the number of tokens the given pool supports.
    function _numTokens(address pool) internal view returns (uint256 numTokens) {
        while (true) {
            // Iterate over the tokens until we get an exception.
            try IDefaultExtendedPool(pool).getToken(uint8(numTokens)) returns (address) {
                unchecked {
                    // unchecked: ++numTokens never overflows uint256
                    ++numTokens;
                }
            } catch {
                // End of pool reached, exit the loop.
                break;
            }
        }
    }

    /// @dev Returns the tokens the given pool supports.
    function _getPoolTokens(address pool) internal view returns (PoolToken[] memory tokens) {
        uint256 numTokens = _numTokens(pool);
        tokens = new PoolToken[](numTokens);
        unchecked {
            // unchecked: ++i never overflows uint256
            for (uint256 i = 0; i < numTokens; ++i) {
                address token = IDefaultExtendedPool(pool).getToken(uint8(i));
                tokens[i] = PoolToken({isWeth: token == _weth, token: token});
            }
        }
    }
}
