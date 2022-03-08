// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/ISwap.sol";
import "./MathUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

contract SwapCalculator {
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

    ISwap public immutable pool;
    IERC20 public immutable lpToken;
    uint256 public immutable numTokens;
    uint256 public swapFee;

    IERC20[] internal poolTokens;
    uint256[] private tokenPrecisionMultipliers;

    uint8 private constant POOL_PRECISION_DECIMALS = 18;
    uint256 private constant A_PRECISION = 100;
    uint256 private constant FEE_DENOMINATOR = 10**10;

    constructor(ISwap _pool) public {
        pool = _pool;
        (, , , , uint256 _swapFee, , address _lpToken) = _pool.swapStorage();
        lpToken = IERC20(_lpToken);
        numTokens = _setPoolTokens(_pool);
        swapFee = _swapFee;
    }

    function updateSwapFee() external {
        (, , , , uint256 _swapFee, , ) = pool.swapStorage();
        swapFee = _swapFee;
    }

    function calculateAddLiquidity(uint256[] memory _amounts)
        external
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

        for (uint8 i = 0; i < _numTokens; i++) {
            v.balances[i] = ISwap(pool).getTokenBalance(i);
            newBalances[i] = v.balances[i].add(_amounts[i]);
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
            uint256 feePerToken = _feePerToken();
            for (uint8 i = 0; i < _numTokens; i++) {
                uint256 idealBalance = v.d1.mul(v.balances[i]).div(v.d0);
                uint256 fees = feePerToken
                .mul(idealBalance.difference(newBalances[i]))
                .div(FEE_DENOMINATOR);
                newBalances[i] = newBalances[i].sub(fees);
            }
            v.d1 = _getD(_xp(newBalances, v.multipliers), v.preciseA);
            return v.d1.sub(v.d0).mul(v.totalSupply).div(v.d0);
        }
    }

    function _setPoolTokens(ISwap _pool) internal returns (uint256) {
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
        poolTokens.push(token);
    }

    /**
     * @notice Get fee applied to each token when adding
     * or removing assets weighted differently from the pool
     */
    function _feePerToken() internal view returns (uint256) {
        return swapFee.mul(numTokens).div(numTokens.sub(1).mul(4));
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
            xp[i] = balances[i].mul(precisionMultipliers[i]);
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
                nA.sub(A_PRECISION).mul(d).div(A_PRECISION).add(
                    _numTokens.add(1).mul(dP)
                )
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
