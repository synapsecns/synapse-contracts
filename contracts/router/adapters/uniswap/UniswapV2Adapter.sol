// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {Adapter} from "../Adapter.sol";
import {AdapterUniversal} from "../tokens/AdapterUniversal.sol";

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";

/// @dev Uniswap adapter supports arbitrary amount of tokens
contract UniswapV2Adapter is Adapter, AdapterUniversal {
    // in base points
    uint256 internal immutable multiplierWithFee;
    uint256 internal constant MULTIPLIER = 10000;

    address public immutable uniswapV2Factory;
    bytes32 internal immutable initCodeHash;

    /**
     * @dev Default UniSwap fee is 0.3% = 30bp
     * @param _fee swap fee, in base points
     */
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _uniswapV2FactoryAddress,
        bytes32 _initCodeHash,
        uint256 _fee
    ) Adapter(_name, _swapGasEstimate) {
        require(_fee < MULTIPLIER, "Fee must be less than multiplier");
        multiplierWithFee = MULTIPLIER - _fee;
        uniswapV2Factory = _uniswapV2FactoryAddress;
        initCodeHash = _initCodeHash;
    }

    function _depositAddress(address _tokenIn, address _tokenOut) internal view override returns (address pair) {
        bytes32 salt = _tokenIn < _tokenOut
            ? keccak256(abi.encodePacked(_tokenIn, _tokenOut))
            : keccak256(abi.encodePacked(_tokenOut, _tokenIn));
        pair = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", uniswapV2Factory, salt, initCodeHash)))));
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        address _pair = _depositAddress(_tokenIn, _tokenOut);
        _amountOut = _getPairAmountOut(_pair, _tokenIn, _tokenOut, _amountIn);
        require(_amountOut > 0, "Insufficient output amount");
        if (_tokenIn < _tokenOut) {
            IUniswapV2Pair(_pair).swap(0, _amountOut, _to, new bytes(0));
        } else {
            IUniswapV2Pair(_pair).swap(_amountOut, 0, _to, new bytes(0));
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        address _pair = _depositAddress(_tokenIn, _tokenOut);
        _amountOut = _getPairAmountOut(_pair, _tokenIn, _tokenOut, _amountIn);
    }

    function _getPairAmountOut(
        address _pair,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) internal view returns (uint256 _amountOut) {
        if (Address.isContract(_pair)) {
            try IUniswapV2Pair(_pair).getReserves() returns (uint112 _reserve0, uint112 _reserve1, uint32) {
                if (_tokenIn < _tokenOut) {
                    _amountOut = _calcAmountOut(_amountIn, _reserve0, _reserve1);
                } else {
                    _amountOut = _calcAmountOut(_amountIn, _reserve1, _reserve0);
                }
            } catch {} // solhint-disable-line no-empty-blocks
        }
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
        uint256 amountInWithFee = _amountIn * multiplierWithFee;
        _amountOut = (amountInWithFee * _reserveOut) / (_reserveIn * MULTIPLIER + amountInWithFee);
    }
}
