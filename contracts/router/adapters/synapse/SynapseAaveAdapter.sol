// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {SynapseBaseAdapter} from "./SynapseBaseAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

interface AaveToken is IERC20 {
    function scaledBalanceOf(address user) external view returns (uint256);
}

contract SynapseAaveAdapter is SynapseBaseAdapter {
    ILendingPool public immutable lendingPool;

    mapping(address => address) public aaveToken;
    mapping(address => bool) public isUnderlying;

    IERC20[] public underlyingTokens;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = RAY / 2;

    /**
     * @param _name Adapter name
     * @param _swapGasEstimate Estimated gas usage for this.swap()
     * @param _pool Pool address
     * @param _lendingPool Aave lending pool address
     * @param _underlyingTokens underlying pool tokens, that will be traded
     */
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool,
        address _lendingPool,
        address[] memory _underlyingTokens
    ) SynapseBaseAdapter(_name, _swapGasEstimate, _pool) {
        require(_underlyingTokens.length == numTokens, "Wrong tokens amount");
        lendingPool = ILendingPool(_lendingPool);

        for (uint8 i = 0; i < _underlyingTokens.length; i++) {
            address poolToken = address(poolTokens[i]);
            address underlyingToken = _underlyingTokens[i];
            if (poolToken != underlyingToken) {
                _registerUnderlying(underlyingToken, poolToken);
            }
            underlyingTokens.push(IERC20(underlyingToken));
        }
    }

    function _registerUnderlying(address underlyingToken, address poolToken)
        internal
    {
        aaveToken[underlyingToken] = poolToken;
        isUnderlying[underlyingToken] = true;
        _setInfiniteAllowance(IERC20(underlyingToken), address(lendingPool));
    }

    function _checkTokens(address tokenIn, address tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        // Swaps are supported between both pool and underlying tokens
        return
            (isUnderlying[tokenIn] || isPoolToken[tokenIn]) &&
            (isUnderlying[tokenOut] || isPoolToken[tokenOut]);
    }

    function _swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) internal virtual override returns (uint256 amountOut) {
        if (isUnderlying[tokenIn]) {
            // Approval already granted in _approveIfNeeded()
            amountIn = _aaveDeposit(tokenIn, amountIn);
            // Swap pool can only trade aToken
            tokenIn = aaveToken[tokenIn];
        }
        if (isUnderlying[tokenOut]) {
            // User needs to receive underlying token, so we ask the aToken to be sent to this contract
            SynapseBaseAdapter._swap(
                amountIn,
                tokenIn,
                aaveToken[tokenOut],
                address(this)
            );
            // Withdraw underlying token directly to user
            amountOut = _aaveWithdraw(tokenOut, UINT_MAX, to);
        } else {
            // User needs to receive pool token, so we can use parent's logic
            amountOut = SynapseBaseAdapter._swap(
                amountIn,
                tokenIn,
                tokenOut,
                to
            );
        }
    }

    function _query(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view virtual override returns (uint256 amountOut) {
        if (isUnderlying[tokenIn]) {
            // figure out how much aTokens will be transferred
            // as pool contract is comparing balances pre/post transfer
            amountIn = _calcTransferredIn(amountIn, tokenIn);
            // replace tokenIn with actual pool token
            tokenIn = aaveToken[tokenIn];
        }

        if (isUnderlying[tokenOut]) {
            uint256 _index = lendingPool.getReserveNormalizedIncome(tokenOut);
            // replace tokenOut with actual pool token
            tokenOut = aaveToken[tokenOut];
            amountOut = SynapseBaseAdapter._query(amountIn, tokenIn, tokenOut);

            amountOut = _calcTransferredOut(amountOut, _index);
        } else {
            amountOut = SynapseBaseAdapter._query(amountIn, tokenIn, tokenOut);
        }
    }

    // -- LIQUIDITY MANAGEMENT: modifiers --

    modifier checkPoolToken(IERC20 token) virtual override {
        require(
            isPoolToken[address(token)] || isUnderlying[address(token)],
            "Unknown token"
        );

        _;
    }

    // -- LIQUIDITY MANAGEMENT: views --

    function calculateRemoveLiquidityOneToken(
        IERC20 _lpToken,
        uint256 lpTokenAmount,
        IERC20 token
    )
        external
        view
        virtual
        override
        checkLpToken(_lpToken)
        checkPoolToken(token)
        returns (uint256 tokenAmount)
    {
        address poolToken = address(token);
        if (isUnderlying[poolToken]) {
            poolToken = aaveToken[poolToken];
        }
        tokenAmount = pool.calculateRemoveLiquidityOneToken(
            lpTokenAmount,
            uint8(tokenIndex[poolToken])
        );
    }

    function getTokens(IERC20 _lpToken)
        external
        view
        virtual
        override
        checkLpToken(_lpToken)
        returns (IERC20[] memory tokens)
    {
        tokens = underlyingTokens;
    }

    function addLiquidity(
        address to,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256 minLpTokensAmount
    )
        external
        virtual
        override
        checkAmounts(amounts)
        returns (uint256 lpTokenAmount)
    {
        require(tokens.length == numTokens, "Wrong amount of tokens");
        uint256[] memory poolAmounts = new uint256[](numTokens);
        for (uint256 index = 0; index < tokens.length; ++index) {
            address token = address(tokens[index]);
            if (isUnderlying[token]) {
                poolAmounts[index] = _aaveDeposit(token, amounts[index]);
                token = aaveToken[token];
            } else if (isPoolToken[token]) {
                poolAmounts[index] = amounts[index];
            } else {
                revert("Unknown token");
            }
            require(tokenIndex[token] == index, "Wrong tokens order");
        }

        // deposit to pool deadlines are checked in Router
        lpTokenAmount = pool.addLiquidity(
            poolAmounts,
            minLpTokensAmount,
            UINT_MAX
        );

        // transfer lp tokens to user
        _returnTo(address(lpToken), lpTokenAmount, to);
    }

    function removeLiquidity(
        address to,
        IERC20 _lpToken,
        uint256 lpTokenAmount,
        uint256[] calldata minTokenAmounts,
        bool unwrapGas,
        IWETH9 wgas
    )
        external
        virtual
        override
        checkLpToken(_lpToken)
        checkAmounts(minTokenAmounts)
        returns (uint256[] memory tokenAmounts)
    {
        tokenAmounts = pool.removeLiquidity(
            lpTokenAmount,
            minTokenAmounts,
            UINT_MAX
        );

        for (uint256 index = 0; index < tokenAmounts.length; ++index) {
            _returnUnwrappedToken(
                to,
                underlyingTokens[index],
                tokenAmounts[index],
                unwrapGas,
                wgas
            );
        }
    }

    function _returnUnwrappedToken(
        address to,
        IERC20 token,
        uint256 amount,
        bool unwrapGas,
        IWETH9 wgas
    ) internal virtual override {
        if (isUnderlying[address(token)]) {
            amount = _aaveWithdraw(address(token), UINT_MAX, address(this));
        }
        super._returnUnwrappedToken(to, token, amount, unwrapGas, wgas);
    }

    // -- AAVE FUNCTIONS

    /// https://github.com/aave/protocol-v2/blob/master/contracts/protocol/libraries/math/WadRayMath.sol
    function _calcTransferredOut(uint256 _amount, uint256 _index)
        internal
        pure
        returns (uint256)
    {
        uint256 rayDiv = (_amount * RAY + _index / 2) / _index;
        return (rayDiv * _index + HALF_RAY) / RAY;
    }

    function _calcTransferredIn(uint256 _amount, address _token)
        internal
        view
        returns (uint256)
    {
        uint256 _index = lendingPool.getReserveNormalizedIncome(_token);

        uint256 _delta = (_amount * RAY + _index / 2) / _index;
        uint256 _oldScaledBalance = AaveToken(aaveToken[_token])
            .scaledBalanceOf(address(pool));

        uint256 _newScaledBalance = _oldScaledBalance + _delta;

        uint256 _oldBalance = (_oldScaledBalance * _index + HALF_RAY) / RAY;
        uint256 _newBalance = (_newScaledBalance * _index + HALF_RAY) / RAY;

        return _newBalance - _oldBalance;
    }

    /**
     * @notice Deposits token into Aave and receives aToken
     *
     * @dev lendingPool should have approval for spending underlying token
     *
     * @param _token underlying token to deposit
     * @param _amount amount of token to deposit
     *
     * @return amount of aToken received
     */
    function _aaveDeposit(address _token, uint256 _amount)
        internal
        returns (uint256)
    {
        lendingPool.deposit(_token, _amount, address(this), 0);
        return IERC20(aaveToken[_token]).balanceOf(address(this));
    }

    /**
     * @notice Withdraw token from Aave and send underlying token to user
     *
     * @dev Chad (lendingPool) doesn't need your approval to spend your aToken.
     * 		Use [to = address(this);] if token needs further (un)wrapping
     *      Use [_amount = UINT_MAX] to withdraw all aToken balance
     *
     * @param _token underlying token to withdraw
     * @param _amount amount of token to withdraw
     * @param to address that will receive underlying token
     *
     * @return amount of underlying token withdrawn
     */
    function _aaveWithdraw(
        address _token,
        uint256 _amount,
        address to
    ) internal returns (uint256) {
        return lendingPool.withdraw(_token, _amount, to);
    }
}
