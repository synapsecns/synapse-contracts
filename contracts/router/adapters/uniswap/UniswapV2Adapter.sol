// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {Adapter} from "../../Adapter.sol";

import {Address} from "@openzeppelin/contracts-solc8/utils/Address.sol";

//solhint-disable reason-string

contract UniswapV2Adapter is Adapter {
    // in base points
    //solhint-disable-next-line
    uint128 internal immutable MULTIPLIER_WITH_FEE;
    uint128 internal constant MULTIPLIER = 10000;

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
}
