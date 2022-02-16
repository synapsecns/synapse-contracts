// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ISynapse.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

contract SwapAddCalculator {
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

    ISynapse public immutable pool;
    IERC20 public immutable lpToken;
    uint256 public immutable numTokens;
    uint256 public swapFee;
    uint256 private swapFeePerToken;

    uint256[] private tokenPrecisionMultipliers;

    uint8 private constant POOL_PRECISION_DECIMALS = 18;
    uint256 private constant A_PRECISION = 100;
    uint256 private constant FEE_DENOMINATOR = 10**10;

    constructor(ISynapse _pool) {
        pool = _pool;
        (, , , , uint256 _swapFee, , address _lpToken) = _pool.swapStorage();
        lpToken = IERC20(_lpToken);
        // set numTokens prior to swapFee
        numTokens = _setPoolTokens(_pool);
        _setSwapFee(_swapFee);
    }

    function updateSwapFee() external {
        (, , , , uint256 _swapFee, , ) = pool.swapStorage();
        _setSwapFee(_swapFee);
    }

    function calculateAddLiquidity(uint256[] memory _amounts)
        public
        view
        returns (uint256)
    {
        require(
            _amounts.length == numTokens,
            "Amounts must match pooled tokens"
        );
        uint256 _numTokens = numTokens;

        ManageLiquidityInfo memory v = ManageLiquidityInfo(
            0,
            0,
            pool.getAPrecise(),
            lpToken.totalSupply(),
            new uint256[](_numTokens),
            tokenPrecisionMultipliers
        );

        uint256[] memory newBalances = new uint256[](_numTokens);

        for (uint8 _i = 0; _i < _numTokens; _i++) {
            v.balances[_i] = ISynapse(pool).getTokenBalance(_i);
            newBalances[_i] = v.balances[_i] + _amounts[_i];
        }

        if (v.totalSupply != 0) {
            v.d0 = _getD(_xp(v.balances, v.multipliers), v.preciseA);
        } else {
            // pool is empty => all amounts must be >0
            for (uint8 i = 0; i < _numTokens; i++) {
                require(_amounts[i] > 0, "Must supply all tokens in pool");
            }
        }

        // invariant after change
        v.d1 = _getD(_xp(newBalances, v.multipliers), v.preciseA);
        require(v.d1 > v.d0, "D should increase");

        if (v.totalSupply == 0) {
            return v.d1;
        } else {
            for (uint256 _i = 0; _i < _numTokens; _i++) {
                uint256 idealBalance = (v.d1 * v.balances[_i]) / v.d0;
                uint256 fees = (swapFeePerToken *
                    _diff(newBalances[_i], idealBalance)) / FEE_DENOMINATOR;
                newBalances[_i] = newBalances[_i] - fees;
            }
            v.d1 = _getD(_xp(newBalances, v.multipliers), v.preciseA);
            return ((v.d1 - v.d0) * v.totalSupply) / v.d0;
        }
    }

    function _setPoolTokens(ISynapse _pool) internal returns (uint256) {
        for (uint8 i = 0; true; i++) {
            try _pool.getToken(i) returns (IERC20 token) {
                _addPoolToken(token, i);
            } catch {
                break;
            }
        }
        return tokenPrecisionMultipliers.length;
    }

    function _addPoolToken(IERC20 token, uint8) internal virtual {
        IERC20Decimals _token = IERC20Decimals(address(token));
        tokenPrecisionMultipliers.push(
            10**uint256(POOL_PRECISION_DECIMALS - _token.decimals())
        );
    }

    function _setSwapFee(uint256 _swapFee) internal {
        swapFee = _swapFee;
        swapFeePerToken = (swapFee * numTokens) / ((numTokens - 1) * 4);
    }

    /**
     * @notice Get absolute difference between two values
     * @return abs(_a - _b)
     */
    function _diff(uint256 _a, uint256 _b) internal pure returns (uint256) {
        if (_a > _b) {
            return _a - _b;
        } else {
            return _b - _a;
        }
    }

    /**
     * @notice Get pool balances adjusted, as if all tokens had 18 decimals
     */
    function _xp(
        uint256[] memory balances,
        uint256[] memory precisionMultipliers
    ) internal pure returns (uint256[] memory) {
        uint256 _numTokens = balances.length;
        require(
            _numTokens == precisionMultipliers.length,
            "Balances must match multipliers"
        );
        uint256[] memory xp = new uint256[](_numTokens);
        for (uint256 i = 0; i < _numTokens; i++) {
            xp[i] = balances[i] * precisionMultipliers[i];
        }
        return xp;
    }

    /**
     * @notice Get D: pool invariant
     */
    function _getD(uint256[] memory xp, uint256 a)
        internal
        pure
        returns (uint256)
    {
        uint256 _numTokens = xp.length;
        uint256 s;
        for (uint256 _i = 0; _i < _numTokens; _i++) {
            s = s + xp[_i];
        }
        if (s == 0) {
            return 0;
        }

        uint256 prevD;
        uint256 d = s;
        uint256 nA = a * _numTokens;

        for (uint256 _i = 0; _i < 256; _i++) {
            uint256 dP = d;
            for (uint256 j = 0; j < _numTokens; j++) {
                dP = (dP * d) / (xp[j] * _numTokens);
                // If we were to protect the division loss we would have to keep the denominator separate
                // and divide at the end. However this leads to overflow with large numTokens or/and D.
                // dP = dP * D * D * D * ... overflow!
            }
            prevD = d;
            d =
                (((nA * s) / A_PRECISION + dP * _numTokens) * d) /
                (((nA - A_PRECISION) * d) /
                    A_PRECISION +
                    (_numTokens + 1) *
                    dP);

            if (_diff(d, prevD) <= 1) {
                return d;
            }
        }

        revert("D does not converge");
    }
}
