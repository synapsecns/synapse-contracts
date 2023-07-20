// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../interfaces/IDefaultPoolCalc.sol";
import {IDefaultExtendedPool} from "../interfaces/IDefaultExtendedPool.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice DefaultPoolCalc is a contract that calculates the amount of LP tokens received
/// for a given amount of tokens deposited into a DefaultPool. This is implemented
/// because the StableSwap pool contract does not expose a function to calculate the EXACT amount,
/// only the ESTIMATED amount: `calculateTokenAmount()`.
contract DefaultPoolCalc is IDefaultPoolCalc {
    // Struct storing variables used in calculations in the
    // {add,remove}Liquidity functions to avoid stack too deep errors
    struct ManageLiquidityInfo {
        uint256 d0;
        uint256 d1;
        uint256 preciseA;
        uint256 totalSupply;
        uint256[] balances;
        uint256[] multipliers;
    }

    uint256 internal constant A_PRECISION = 100;
    uint256 internal constant FEE_DENOMINATOR = 10**10;

    // Copied from the Saddle repo with state changes omitted: https://github.com/saddle-finance/saddle-contract/
    // blob/5d538c47115c29990dea5aa8af679bd024c82e35/contracts/SwapUtilsV2.sol#L717

    /// @inheritdoc IDefaultPoolCalc
    function calculateAddLiquidity(address pool, uint256[] memory amounts) external view returns (uint256 amountOut) {
        uint256 numTokens = amounts.length;
        // Verify that `numTokens >= pool.tokens.length`
        _verifyTokensAmount(pool, numTokens);
        (, , , , uint256 swapFee, , address lpToken) = IDefaultExtendedPool(pool).swapStorage();
        // current state
        ManageLiquidityInfo memory v = ManageLiquidityInfo({
            d0: 0,
            d1: 0,
            preciseA: IDefaultExtendedPool(pool).getAPrecise(),
            totalSupply: IERC20Metadata(lpToken).totalSupply(),
            balances: new uint256[](numTokens),
            multipliers: new uint256[](numTokens)
        });
        uint256[] memory newBalances = new uint256[](numTokens);
        // If `numTokens < pool.tokens.length`, the loop will revert
        for (uint256 i = 0; i < numTokens; ++i) {
            address token = IDefaultExtendedPool(pool).getToken(uint8(i));
            v.balances[i] = IDefaultExtendedPool(pool).getTokenBalance(uint8(i));
            newBalances[i] = v.balances[i] + amounts[i];
            v.multipliers[i] = 10**(18 - IERC20Metadata(token).decimals());
        }
        // At this point we verified that `numTokens == pool.tokens.length`
        if (v.totalSupply != 0) {
            v.d0 = _getD(_xp(v.balances, v.multipliers), v.preciseA);
        } else {
            for (uint256 i = 0; i < numTokens; ++i) {
                require(amounts[i] > 0, "Must supply all tokens in pool");
            }
        }

        // invariant after change
        v.d1 = _getD(_xp(newBalances, v.multipliers), v.preciseA);
        require(v.d1 > v.d0, "D should increase");

        if (v.totalSupply == 0) {
            return v.d1;
        } else {
            uint256 feePerToken = _feePerToken(swapFee, numTokens);
            for (uint256 i = 0; i < numTokens; ++i) {
                uint256 idealBalance = (v.d1 * v.balances[i]) / v.d0;
                uint256 fees = (feePerToken * _difference(idealBalance, newBalances[i])) / FEE_DENOMINATOR;
                newBalances[i] -= fees;
            }
            v.d1 = _getD(_xp(newBalances, v.multipliers), v.preciseA);
            return ((v.d1 - v.d0) * v.totalSupply) / v.d0;
        }
    }

    /// @dev Verifies that the given pool has AT MOST `numTokens` tokens.
    function _verifyTokensAmount(address pool, uint256 numTokens) internal view {
        // Getting token with index == amount should always revert
        try IDefaultExtendedPool(pool).getToken(uint8(numTokens)) returns (address) {
            revert("Incorrect tokens amount");
        } catch {} // solhint-disable-line no-empty-blocks
    }

    // ═════════════════════════════════════════════ STABLE SWAP MATH ══════════════════════════════════════════════════

    // Copied from https://github.com/saddle-finance/saddle-contract/blob/master/contracts/SwapUtilsV2.sol

    /// @dev Returns abs(a-b).
    function _difference(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**
     * @notice Get D, the StableSwap invariant, based on a set of balances and a particular A.
     * @param xp a precision-adjusted set of pool balances. Array should be the same cardinality
     * as the pool.
     * @param a the amplification coefficient * n * (n - 1) in A_PRECISION.
     * See the StableSwap paper for details
     * @return the invariant, at the precision of the pool
     */
    function _getD(uint256[] memory xp, uint256 a) internal pure returns (uint256) {
        uint256 numTokens = xp.length;
        uint256 s;
        for (uint256 i = 0; i < numTokens; i++) {
            s = s + xp[i];
        }
        if (s == 0) {
            return 0;
        }

        uint256 prevD;
        uint256 d = s;
        uint256 nA = a * numTokens;

        for (uint256 i = 0; i < 256; i++) {
            uint256 dP = d;
            for (uint256 j = 0; j < numTokens; j++) {
                dP = (dP * d) / (xp[j] * numTokens);
                // If we were to protect the division loss we would have to keep the denominator separate
                // and divide at the end. However this leads to overflow with large numTokens or/and D.
                // dP = dP * D * D * D * ... overflow!
            }
            prevD = d;
            d =
                ((((nA * s) / A_PRECISION) + (dP * numTokens)) * d) /
                ((((nA - A_PRECISION) * d) / A_PRECISION) + ((numTokens + 1) * dP));

            if (_difference(d, prevD) <= 1) {
                return d;
            }
        }

        // Convergence should occur in 4 loops or less. If this is reached, there may be something wrong
        // with the pool. If this were to occur repeatedly, LPs should withdraw via `removeLiquidity()`
        // function which does not rely on D.
        revert("D does not converge");
    }

    /**
     * @notice internal helper function to calculate fee per token multiplier used in
     * swap fee calculations
     * @param swapFee swap fee for the tokens
     * @param numTokens number of tokens pooled
     */
    function _feePerToken(uint256 swapFee, uint256 numTokens) internal pure returns (uint256) {
        return ((swapFee * numTokens) / ((numTokens - 1) * 4));
    }

    /**
     * @notice Given a set of balances and precision multipliers, return the
     * precision-adjusted balances.
     *
     * @param balances an array of token balances, in their native precisions.
     * These should generally correspond with pooled tokens.
     *
     * @param precisionMultipliers an array of multipliers, corresponding to
     * the amounts in the balances array. When multiplied together they
     * should yield amounts at the pool's precision.
     *
     * @return an array of amounts "scaled" to the pool's precision
     */
    function _xp(uint256[] memory balances, uint256[] memory precisionMultipliers)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 numTokens = balances.length;
        require(numTokens == precisionMultipliers.length, "Balances must match multipliers");
        uint256[] memory xp = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            xp[i] = balances[i] * precisionMultipliers[i];
        }
        return xp;
    }
}
