// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISynapse} from "../interfaces/ISynapse.sol";

import {LiquidityAdapter} from "../LiquidityAdapter.sol";
import {Adapter} from "../../Adapter.sol";
import {SwapCalculator} from "../../helper/SwapCalculator.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

//solhint-disable not-rely-on-time

contract SynapseBaseAdapter is SwapCalculator, Adapter, LiquidityAdapter {
    mapping(address => bool) public isPoolToken;
    mapping(address => uint256) public tokenIndex;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _pool
    ) SwapCalculator(ISynapse(_pool)) Adapter(_name, _swapGasEstimate) {
        // Allow pool to spend LP token => used for withdrawals
        _setInfiniteAllowance(lpToken, _pool);
    }

    function _addPoolToken(IERC20 token, uint256 index)
        internal
        virtual
        override
    {
        SwapCalculator._addPoolToken(token, index);
        _registerPoolToken(token, index);
    }

    function _registerPoolToken(IERC20 token, uint256 index) internal {
        isPoolToken[address(token)] = true;
        tokenIndex[address(token)] = index;
        _setInfiniteAllowance(token, address(pool));
    }

    function _checkTokens(address tokenIn, address tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return isPoolToken[tokenIn] && isPoolToken[tokenOut];
    }

    function _depositAddress(address, address)
        internal
        view
        override
        returns (address)
    {
        return address(this);
    }

    function _swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) internal virtual override returns (uint256 amountOut) {
        amountOut = pool.swap(
            uint8(tokenIndex[tokenIn]),
            uint8(tokenIndex[tokenOut]),
            amountIn,
            0,
            block.timestamp
        );

        _returnTo(tokenOut, amountOut, to);
    }

    function _query(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view virtual override returns (uint256 amountOut) {
        if (pool.paused()) {
            return 0;
        }
        try
            pool.calculateSwap(
                uint8(tokenIndex[tokenIn]),
                uint8(tokenIndex[tokenOut]),
                amountIn
            )
        returns (uint256 _amountOut) {
            amountOut = _amountOut;
        } catch {
            return 0;
        }
    }

    // -- LIQUIDITY MANAGEMENT: modifiers --

    modifier checkAmounts(uint256[] calldata amounts) {
        require(amounts.length == numTokens, "Wrong amount of tokens");

        _;
    }

    modifier checkLpToken(IERC20 _lpToken) {
        require(address(_lpToken) == address(lpToken), "Unknown LP token");

        _;
    }

    modifier checkPoolToken(IERC20 token) virtual {
        require(isPoolToken[address(token)], "Unknown token");

        _;
    }

    // -- LIQUIDITY MANAGEMENT: views --

    function calculateAddLiquidity(
        IERC20[] calldata,
        uint256[] calldata amountsMax
    )
        external
        view
        checkAmounts(amountsMax)
        returns (uint256 lpTokenAmount, uint256[] memory refund)
    {
        lpTokenAmount = calculateAddLiquidity(amountsMax);
        // All tokens are provided to the pool => no refund
        refund = new uint256[](numTokens);
    }

    function calculateRemoveLiquidity(IERC20 _lpToken, uint256 lpTokenAmount)
        external
        view
        checkLpToken(_lpToken)
        returns (uint256[] memory tokenAmounts)
    {
        tokenAmounts = pool.calculateRemoveLiquidity(lpTokenAmount);
    }

    function calculateRemoveLiquidityOneToken(
        IERC20 _lpToken,
        uint256 lpTokenAmount,
        IERC20 token
    )
        external
        view
        virtual
        checkLpToken(_lpToken)
        checkPoolToken(token)
        returns (uint256 tokenAmount)
    {
        tokenAmount = pool.calculateRemoveLiquidityOneToken(
            lpTokenAmount,
            uint8(tokenIndex[address(token)])
        );
    }

    function getTokens(IERC20 _lpToken)
        external
        view
        virtual
        checkLpToken(_lpToken)
        returns (IERC20[] memory tokens)
    {
        tokens = poolTokens;
    }

    function getTokensDepositInfo(
        IERC20[] calldata,
        uint256[] calldata amountsMax
    )
        external
        view
        returns (address liquidityDepositAddress, uint256[] memory amounts)
    {
        liquidityDepositAddress = address(this);
        // All tokens are provided to the pool
        amounts = amountsMax;
    }

    function getLpTokenDepositAddress(IERC20)
        external
        view
        returns (address liquidityDepositAddress)
    {
        return address(this);
    }

    // -- LIQUIDITY MANAGEMENT: interactions --

    function addLiquidity(
        address to,
        IERC20[] calldata,
        uint256[] calldata amounts,
        uint256 minLpTokensAmount
    ) external virtual checkAmounts(amounts) returns (uint256 lpTokenAmount) {
        // deposit to pool deadlines are checked in Router
        lpTokenAmount = pool.addLiquidity(amounts, minLpTokensAmount, UINT_MAX);

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
                poolTokens[index],
                tokenAmounts[index],
                unwrapGas,
                wgas
            );
        }
    }

    function removeLiquidityOneToken(
        address to,
        IERC20 _lpToken,
        uint256 lpTokenAmount,
        IERC20 token,
        uint256 minTokenAmount,
        bool unwrapGas,
        IWETH9 wgas
    )
        external
        virtual
        checkLpToken(_lpToken)
        checkPoolToken(token)
        returns (uint256 tokenAmount)
    {
        tokenAmount = pool.removeLiquidityOneToken(
            lpTokenAmount,
            uint8(tokenIndex[address(token)]),
            minTokenAmount,
            UINT_MAX
        );

        _returnUnwrappedToken(to, token, tokenAmount, unwrapGas, wgas);
    }
}
