// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISynapse} from "../../interfaces/ISynapse.sol";
import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../../interfaces/IUniswapV2Pair.sol";

import {Adapter} from "../../Adapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

contract UniswapV2Adapter is Adapter {
    IUniswapV2Factory public uniswapV2Factory;

    // storage for already known pairs
    mapping(address => mapping(address => address)) private pairs;

    // in base points
    uint256 internal immutable MULTIPLIER_WITH_FEE;
    uint256 internal constant MULTIPLIER = 10000;

    /**
     * @dev Default UniSwap fee is 0.3% = 30bp
     * @param _fee swap fee, in base points
     */
    constructor(
        string memory _name,
        address _uniswapV2FactoryAddress,
        uint256 _swapGasEstimate,
        uint256 _fee
    ) Adapter(_name, _swapGasEstimate) {
        require(
            _fee < MULTIPLIER,
            "Fee is too high. Must be less than multiplier"
        );
        MULTIPLIER_WITH_FEE = MULTIPLIER - _fee;
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2FactoryAddress);
    }

    function _approveIfNeeded(address, uint256) internal virtual override {
        this;
    }

    function _depositAddress(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (address)
    {
        return
            pairs[_tokenIn][_tokenOut] == address(0)
                ? uniswapV2Factory.getPair(_tokenIn, _tokenOut)
                : pairs[_tokenIn][_tokenOut];
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        address _pair = _getPair(_tokenIn, _tokenOut);
        // _amountIn and _pair are already checked
        _amountOut = _getPairAmountOut(_pair, _tokenIn, _tokenOut, _amountIn);
        require(_amountOut > 0, "Adapter: Insufficient output amount");
        (uint256 _amount0Out, uint256 _amount1Out) = _tokenIn < _tokenOut
            ? (uint256(0), _amountOut)
            : (_amountOut, uint256(0));

        IUniswapV2Pair(_pair).swap(_amount0Out, _amount1Out, _to, new bytes(0));
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        address _pair = _depositAddress(_tokenIn, _tokenOut);
        // _pair is already checked
        _amountOut = _getPairAmountOut(_pair, _tokenIn, _tokenOut, _amountIn);
    }

    function _getPair(address _tokenA, address _tokenB)
        internal
        returns (address)
    {
        if (pairs[_tokenA][_tokenB] == address(0)) {
            address _pair = _depositAddress(_tokenA, _tokenB);

            // save the pair address for both A->B and B->A directions
            pairs[_tokenA][_tokenB] = _pair;
            pairs[_tokenB][_tokenA] = _pair;
        }
        return pairs[_tokenA][_tokenB];
    }

    function _getReserves(
        address _pair,
        address _tokenA,
        address _tokenB
    ) internal view returns (uint256 _reserveA, uint256 _reserveB) {
        (uint256 _reserve0, uint256 _reserve1, ) = IUniswapV2Pair(_pair)
            .getReserves();
        (_reserveA, _reserveB) = _tokenA < _tokenB
            ? (_reserve0, _reserve1)
            : (_reserve1, _reserve0);
    }

    function _getPairAmountOut(
        address _pair,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) internal view returns (uint256 _amountOut) {
        (uint256 _reserveIn, uint256 _reserveOut) = _getReserves(
            _pair,
            _tokenIn,
            _tokenOut
        );
        return _calcAmountOut(_amountIn, _reserveIn, _reserveOut);
    }

    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return _depositAddress(_tokenIn, _tokenOut) != address(0);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function _calcAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) internal view returns (uint256 _amountOut) {
        if (_reserveIn == 0 || _reserveOut == 0) {
            return 0;
        }
        uint256 amountInWithFee = _amountIn * MULTIPLIER_WITH_FEE;
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = _reserveIn * MULTIPLIER + amountInWithFee;

        _amountOut = numerator / denominator;
    }
}
