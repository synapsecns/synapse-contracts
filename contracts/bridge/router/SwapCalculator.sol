// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../interfaces/ISwap.sol";
import "../interfaces/ISwapQuoter.sol";
import "../../amm/MathUtils.sol";

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

abstract contract SwapCalculator is ISwapQuoter {
    using EnumerableSet for EnumerableSet.AddressSet;

    using SafeMath for uint256;
    using MathUtils for uint256;

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

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                              CONSTANTS                               ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    uint256 private constant POOL_PRECISION_DECIMALS = 18;
    uint256 private constant A_PRECISION = 100;
    uint256 private constant FEE_DENOMINATOR = 10**10;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Set of supported pools conforming to ISwap interface
    EnumerableSet.AddressSet internal _pools;
    /// @dev Pool tokens for every supported ISwap pool
    mapping(address => address[]) internal _poolTokens;
    /// @dev LP token for every supported ISwap pool (if exists)
    mapping(address => address) internal _poolLpToken;
    /// @dev Pool precision multipliers for every supported ISwap pool
    mapping(address => uint256[]) internal _poolMultipliers;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            EXTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Returns the exact quote for adding liquidity to a given pool
     * in a form of a single token.
     * @dev Apparently, the StableSwap authors didn't consider such function worth implementing,
     * as the only way to get a quote for adding liquidity would be calculateTokenAmount(),
     * which gives an ESTIMATE: it doesn't take the trade fees into account.
     * We do need the exact quotes for (DAI/USDC/USDT) -> nUSD swaps on Mainnet, hence we do this.
     * The code is copied from SwapUtils.addLiquidity(), with all the state changes omitted.
     * Note: the function might revert instead of returning 0 for incorrect requests. Make sure
     * to take that into account (see {_calculateAdd}, which is using this).
     */
    function calculateAddLiquidity(address pool, uint256[] memory amounts)
        external
        view
        override
        returns (uint256 amountOut)
    {
        uint256 numTokens = _poolTokens[pool].length;
        require(amounts.length == numTokens, "Amounts must match pooled tokens");
        ManageLiquidityInfo memory v = ManageLiquidityInfo({
            d0: 0,
            d1: 0,
            preciseA: ISwap(pool).getAPrecise(),
            totalSupply: IERC20(_poolLpToken[pool]).totalSupply(),
            balances: new uint256[](numTokens),
            multipliers: _poolMultipliers[pool]
        });

        uint256[] memory newBalances = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; ++i) {
            v.balances[i] = ISwap(pool).getTokenBalance(uint8(i));
            newBalances[i] = v.balances[i].add(amounts[i]);
        }

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
            (, , , , uint256 swapFee, , ) = ISwap(pool).swapStorage();
            uint256 feePerToken = _feePerToken(swapFee, numTokens);
            for (uint256 i = 0; i < numTokens; ++i) {
                uint256 idealBalance = v.d1.mul(v.balances[i]).div(v.d0);
                uint256 fees = feePerToken.mul(idealBalance.difference(newBalances[i])).div(FEE_DENOMINATOR);
                newBalances[i] = newBalances[i].sub(fees);
            }
            v.d1 = _getD(_xp(newBalances, v.multipliers), v.preciseA);
            return v.d1.sub(v.d0).mul(v.totalSupply).div(v.d0);
        }
    }

    /**
     * @notice Returns the exact quote for swapping between two given tokens.
     * @dev Exposes ISwap.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
     */
    function calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view override returns (uint256 amountOut) {
        amountOut = ISwap(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    /**
     * @notice Returns the exact quote for withdrawing pools tokens in a balanced way.
     * @dev Exposes ISwap.calculateRemoveLiquidity(amount);
     */
    function calculateRemoveLiquidity(address pool, uint256 amount)
        external
        view
        override
        returns (uint256[] memory amountsOut)
    {
        amountsOut = ISwap(pool).calculateRemoveLiquidity(amount);
    }

    /**
     * @notice Returns the exact quote for withdrawing a single pool token.
     * @dev Exposes ISwap.calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
     */
    function calculateWithdrawOneToken(
        address pool,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view override returns (uint256 amountOut) {
        amountOut = ISwap(pool).calculateRemoveLiquidityOneToken(tokenAmount, tokenIndex);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _addPool(address pool) internal {
        if (_pools.add(pool)) {
            address[] storage tokens = _poolTokens[pool];
            // Don't do anything if pool was added before
            if (tokens.length != 0) return;
            for (uint8 i = 0; ; ++i) {
                try ISwap(pool).getToken(i) returns (IERC20 token) {
                    uint256 decimals = ERC20(address(token)).decimals();
                    _poolTokens[pool].push(address(token));
                    _poolMultipliers[pool].push(10**POOL_PRECISION_DECIMALS.sub(decimals));
                } catch {
                    // End of pool reached
                    break;
                }
            }
            try ISwap(pool).swapStorage() returns (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                address lpToken
            ) {
                _poolLpToken[pool] = lpToken;
            } catch {
                // solhint-disable-previous-line no-empty-blocks
                // Don't do anything if swapStorage fails,
                // this is probably a wrapper pool
            }
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            INTERNAL VIEWS                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _calculateSwap(
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        try ISwap(pool).calculateSwap(tokenIndexFrom, tokenIndexTo, amountIn) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    function _calculateRemove(
        address pool,
        uint8 tokenIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        try ISwap(pool).calculateRemoveLiquidityOneToken(amountIn, tokenIndexTo) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    function _calculateAdd(
        address pool,
        uint8 tokenIndexFrom,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        uint256[] memory amounts = new uint256[](_poolTokens[pool].length);
        amounts[tokenIndexFrom] = amountIn;
        // In order to keep the code clean, we do an external call to ourselves here
        // and return 0 should the execution be reverted.
        try this.calculateAddLiquidity(pool, amounts) returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    /**
     * @notice Returns indexes for the two given tokens plus 1.
     * The default value of 0 means a token is not supported by the pool.
     */
    function _getTokenIndexes(
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint8 indexIn, uint8 indexOut) {
        address[] storage tokens = _poolTokens[pool];
        uint256 amount = tokens.length;
        for (uint8 t = 0; t < amount; ++t) {
            address poolToken = tokens[t];
            if (poolToken == tokenIn) {
                indexIn = t + 1;
            } else if (poolToken == tokenOut) {
                indexOut = t + 1;
            }
        }
    }

    /**
     * @notice Get fee applied to each token when adding
     * or removing assets weighted differently from the pool
     */
    function _feePerToken(uint256 swapFee, uint256 numTokens) internal pure returns (uint256) {
        return swapFee.mul(numTokens).div(numTokens.sub(1).mul(4));
    }

    /**
     * @notice Get pool balances adjusted, as if all tokens had 18 decimals
     */
    function _xp(uint256[] memory balances, uint256[] memory precisionMultipliers)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 _numTokens = balances.length;
        require(_numTokens == precisionMultipliers.length, "Balances must match multipliers");
        uint256[] memory xp = new uint256[](_numTokens);
        for (uint256 i = 0; i < _numTokens; i++) {
            xp[i] = balances[i].mul(precisionMultipliers[i]);
        }
        return xp;
    }

    /**
     * @notice Get D: pool invariant
     */
    function _getD(uint256[] memory xp, uint256 a) internal pure returns (uint256) {
        uint256 _numTokens = xp.length;
        uint256 s;
        for (uint256 i = 0; i < _numTokens; i++) {
            s = s.add(xp[i]);
        }
        if (s == 0) {
            return 0;
        }

        uint256 prevD;
        uint256 d = s;
        uint256 nA = a.mul(_numTokens);

        for (uint256 i = 0; i < 256; i++) {
            uint256 dP = d;
            for (uint256 j = 0; j < _numTokens; j++) {
                dP = dP.mul(d).div(xp[j].mul(_numTokens));
                // If we were to protect the division loss we would have to keep the denominator separate
                // and divide at the end. However this leads to overflow with large numTokens or/and D.
                // dP = dP * D * D * D * ... overflow!
            }
            prevD = d;
            d = nA.mul(s).div(A_PRECISION).add(dP.mul(_numTokens)).mul(d).div(
                nA.sub(A_PRECISION).mul(d).div(A_PRECISION).add(_numTokens.add(1).mul(dP))
            );
            if (d.within1(prevD)) {
                return d;
            }
        }

        // Convergence should occur in 4 loops or less. If this is reached, there may be something wrong
        // with the pool. If this were to occur repeatedly, LPs should withdraw via `removeLiquidity()`
        // function which does not rely on D.
        revert("D does not converge");
    }
}
