// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../../Adapter.sol";
import {LiquidityAdapter} from "../LiquidityAdapter.sol";

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";

import {Math} from "../../libraries/Math.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";

import {Address} from "@openzeppelin/contracts-solc8/utils/Address.sol";

//solhint-disable reason-string

contract UniswapV2Adapter is Adapter, LiquidityAdapter {
    // in base points
    //solhint-disable-next-line
    uint128 internal immutable MULTIPLIER_WITH_FEE;
    uint128 internal constant MULTIPLIER = 10000;

    uint256 internal constant MINIMUM_LIQUIDITY = 10**3;

    address public immutable uniswapV2Factory;
    bytes32 internal immutable initCodeHash;

    /**
     * @dev Default UniSwap fee is 0.3% = 30bp
     * @param _fee swap fee, in base points
     */
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _uniswapV2Factory,
        bytes32 _initCodeHash,
        uint256 _fee
    ) Adapter(_name, _swapGasEstimate) {
        require(
            _fee < MULTIPLIER,
            "Fee is too high. Must be less than multiplier"
        );
        MULTIPLIER_WITH_FEE = uint128(MULTIPLIER - _fee);
        uniswapV2Factory = _uniswapV2Factory;
        initCodeHash = _initCodeHash;
    }

    function _depositAddress(address tokenIn, address tokenOut)
        internal
        view
        override
        returns (address pair)
    {
        bytes32 salt = tokenIn < tokenOut
            ? keccak256(abi.encodePacked(tokenIn, tokenOut))
            : keccak256(abi.encodePacked(tokenOut, tokenIn));
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            uniswapV2Factory,
                            salt,
                            initCodeHash
                        )
                    )
                )
            )
        );
    }

    function _swap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address to
    ) internal virtual override returns (uint256 amountOut) {
        address pair = _depositAddress(tokenIn, tokenOut);

        amountOut = _getPairAmountOut(pair, tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Adapter: Insufficient output amount");

        if (tokenIn < tokenOut) {
            IUniswapV2Pair(pair).swap(0, amountOut, to, new bytes(0));
        } else {
            IUniswapV2Pair(pair).swap(amountOut, 0, to, new bytes(0));
        }
    }

    function _query(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view virtual override returns (uint256 amountOut) {
        address pair = _depositAddress(tokenIn, tokenOut);

        amountOut = _getPairAmountOut(pair, tokenIn, tokenOut, amountIn);
    }

    function _getPairAmountOut(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        if (Address.isContract(pair)) {
            try IUniswapV2Pair(pair).getReserves() returns (
                uint112 reserve0,
                uint112 reserve1,
                uint32
            ) {
                if (tokenIn < tokenOut) {
                    amountOut = _calcAmountOut(amountIn, reserve0, reserve1);
                } else {
                    amountOut = _calcAmountOut(amountIn, reserve1, reserve0);
                }
            } catch {
                this;
            }
        }
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function _calcAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountOut) {
        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }
        uint256 amountInWithFee = amountIn * MULTIPLIER_WITH_FEE;

        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn * MULTIPLIER + amountInWithFee);
    }

    // -- LIQUIDITY MANAGEMENT: modifiers --

    modifier checkAmounts(
        IERC20[] calldata tokens,
        uint256[] calldata amounts
    ) {
        require(
            tokens.length == 2 && amounts.length == 2,
            "Wrong amount of tokens"
        );

        _;
    }

    // -- LIQUIDITY MANAGEMENT: views --

    function calculateAddLiquidity(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    )
        external
        view
        checkAmounts(tokens, amountsMax)
        returns (uint256 lpTokenAmount, uint256[] memory amounts)
    {
        (, lpTokenAmount, amounts) = _getFullDepositInfo(tokens, amountsMax);
    }

    function calculateRemoveLiquidity(IERC20 lpToken, uint256 lpTokenAmount)
        external
        view
        returns (uint256[] memory tokenAmounts)
    {
        uint256 totalSupply = lpToken.totalSupply();
        (IERC20 token0, IERC20 token1) = _getTokens(lpToken);
        tokenAmounts = new uint256[](2);

        tokenAmounts[0] =
            (token0.balanceOf(address(lpToken)) * lpTokenAmount) /
            totalSupply;

        tokenAmounts[1] =
            (token1.balanceOf(address(lpToken)) * lpTokenAmount) /
            totalSupply;
    }

    function calculateRemoveLiquidityOneToken(
        IERC20 lpToken,
        uint256 lpTokenAmount,
        IERC20 token
    ) external view returns (uint256 tokenAmount) {
        uint256 totalSupply = lpToken.totalSupply();
        (IERC20 token0, IERC20 token1) = _getTokens(lpToken);

        uint256 amount0 = (token0.balanceOf(address(lpToken)) * lpTokenAmount) /
            totalSupply;

        uint256 amount1 = (token1.balanceOf(address(lpToken)) * lpTokenAmount) /
            totalSupply;

        uint256 reserve0 = token0.balanceOf(address(lpToken)) - amount0;
        uint256 reserve1 = token1.balanceOf(address(lpToken)) - amount1;

        if (address(token) == address(token0)) {
            // keep: token0 + swap: token1 -> token0
            tokenAmount = amount0 + _calcAmountOut(amount1, reserve1, reserve0);
        } else if (address(token) == address(token1)) {
            // keep: token1 + swap: token0 -> token1
            tokenAmount = amount1 + _calcAmountOut(amount0, reserve0, reserve1);
        } else {
            revert("Unknown token");
        }
    }

    function getTokens(IERC20 lpToken)
        public
        view
        returns (IERC20[] memory tokens, uint256[] memory balances)
    {
        tokens = new IERC20[](2);
        (tokens[0], tokens[1]) = _getTokens(lpToken);

        balances = new uint256[](2);
        (balances[0], balances[1], ) = Address.isContract(address(lpToken))
            ? IUniswapV2Pair(address(lpToken)).getReserves()
            : (uint112(0), uint112(0), uint32(0));
    }

    function _getTokens(IERC20 lpToken)
        internal
        view
        returns (IERC20 token0, IERC20 token1)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(address(lpToken));
        (token0, token1) = (IERC20(pair.token0()), IERC20(pair.token1()));
    }

    function getTokensDepositInfo(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    )
        external
        view
        checkAmounts(tokens, amountsMax)
        returns (address liquidityDepositAddress, uint256[] memory amounts)
    {
        (liquidityDepositAddress, , amounts) = _getFullDepositInfo(
            tokens,
            amountsMax
        );
    }

    function getLpTokenDepositAddress(IERC20 lpToken)
        external
        pure
        returns (address liquidityDepositAddress)
    {
        return address(lpToken);
    }

    function _getFullDepositInfo(
        IERC20[] calldata tokens,
        uint256[] calldata amountsMax
    )
        internal
        view
        returns (
            address lpToken,
            uint256 lpTokenAmount,
            uint256[] memory amounts
        )
    {
        lpToken = _depositAddress(address(tokens[0]), address(tokens[1]));
        (uint112 reserve0, uint112 reserve1, ) = Address.isContract(lpToken)
            ? IUniswapV2Pair(lpToken).getReserves()
            : (uint112(0), uint112(0), uint32(0));

        uint256 amount0;
        uint256 amount1;

        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amountsMax[0], amountsMax[1]);
            lpTokenAmount = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        } else {
            uint256 totalSupply = IERC20(lpToken).totalSupply();
            amount0 = amountsMax[0];
            amount1 = _quote(amount0, reserve0, reserve1);
            if (amount1 > amountsMax[1]) {
                amount1 = amountsMax[1];
                amount0 = _quote(amount1, reserve1, reserve0);
                // Sanity check
                assert(amount0 <= amountsMax[0]);
            }
            lpTokenAmount = Math.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }

        amounts = new uint256[](2);
        (amounts[0], amounts[1]) = (amount0, amount1);
    }

    function _quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(reserveA > 0 && reserveB > 0, "INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // -- LIQUIDITY MANAGEMENT: interactions --

    function addLiquidity(
        address to,
        IERC20[] calldata tokens,
        uint256[] calldata,
        uint256 minLpTokensAmount
    ) external returns (uint256 lpTokenAmount) {
        // Tokens should be already in pair contract
        address pair = _depositAddress(address(tokens[0]), address(tokens[1]));
        if (!Address.isContract(pair)) {
            // create a pair if it does not exist yet
            IUniswapV2Factory(uniswapV2Factory).createPair(
                address(tokens[0]),
                address(tokens[1])
            );
        }

        lpTokenAmount = IUniswapV2Pair(pair).mint(to);
        require(lpTokenAmount >= minLpTokensAmount, "Insufficient output: LP");
    }

    function removeLiquidity(
        address to,
        IERC20 lpToken,
        uint256,
        uint256[] calldata minTokenAmounts,
        bool unwrapGas,
        IWETH9 wgas
    ) external returns (uint256[] memory tokenAmounts) {
        // lpTokens should be already transferred to pair address
        (IERC20 token0, IERC20 token1) = _getTokens(lpToken);
        tokenAmounts = new uint256[](2);
        if (
            unwrapGas &&
            (address(wgas) == address(token0) ||
                address(wgas) == address(token1))
        ) {
            // Withdraw liquidity to Adapter
            (tokenAmounts[0], tokenAmounts[1]) = IUniswapV2Pair(
                address(lpToken)
            ).burn(address(this));
            // Unwrap and return to user
            _returnUnwrappedToken(to, token0, tokenAmounts[0], unwrapGas, wgas);
            _returnUnwrappedToken(to, token1, tokenAmounts[1], unwrapGas, wgas);
        } else {
            // Withdraw directly to user
            (tokenAmounts[0], tokenAmounts[1]) = IUniswapV2Pair(
                address(lpToken)
            ).burn(to);
        }
        require(
            tokenAmounts[0] >= minTokenAmounts[0],
            "Insufficient output: 0"
        );
        require(
            tokenAmounts[1] >= minTokenAmounts[1],
            "Insufficient output: 1"
        );
    }

    // solhint-disable-next-line
    struct _RemoveOneInfo {
        IERC20 token0;
        IERC20 token1;
        uint256 amount0;
        uint256 amount1;
        uint256 reserve0;
        uint256 reserve1;
    }

    function removeLiquidityOneToken(
        address to,
        IERC20 lpToken,
        uint256,
        IERC20 token,
        uint256 minTokenAmount,
        bool unwrapGas,
        IWETH9 wgas
    ) external returns (uint256 tokenAmount) {
        _RemoveOneInfo memory info;

        // lpTokens should be already transferred to pair address
        (info.token0, info.token1) = _getTokens(lpToken);
        // Withdraw directly to Adapter
        (info.amount0, info.amount1) = IUniswapV2Pair(address(lpToken)).burn(
            address(this)
        );

        info.reserve0 = info.token0.balanceOf(address(lpToken));
        info.reserve1 = info.token1.balanceOf(address(lpToken));

        if (address(token) == address(info.token0)) {
            // keep: token0 + swap: token1 -> token0
            uint256 amountSwap0 = _calcAmountOut(
                info.amount1,
                info.reserve1,
                info.reserve0
            );
            tokenAmount = info.amount0 + amountSwap0;
            require(tokenAmount >= minTokenAmount, "Insufficient output: 0");

            // Transfer token1 to pair contract in preparation for swap
            _returnTo(address(info.token1), info.amount1, address(lpToken));
            IUniswapV2Pair(address(lpToken)).swap(
                amountSwap0,
                0,
                address(this),
                new bytes(0)
            );
        } else if (address(token) == address(info.token1)) {
            // keep: token1 + swap: token0 -> token1
            uint256 amountSwap1 = _calcAmountOut(
                info.amount0,
                info.reserve0,
                info.reserve1
            );
            tokenAmount = info.amount1 + amountSwap1;
            require(tokenAmount >= minTokenAmount, "Insufficient output: 1");

            // Transfer token0 to pair contract in preparation for swap
            _returnTo(address(info.token0), info.amount0, address(lpToken));
            IUniswapV2Pair(address(lpToken)).swap(
                0,
                amountSwap1,
                address(this),
                new bytes(0)
            );
        } else {
            revert("Unknown token");
        }

        // return withdrawn + swapped tokens ot user
        _returnUnwrappedToken(to, token, tokenAmount, unwrapGas, wgas);
    }
}
