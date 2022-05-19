// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISolidlyPair} from "../interfaces/ISolidlyPair.sol";
import {Adapter} from "../../Adapter.sol";

import {Address} from "@openzeppelin/contracts-4.5.0/utils/Address.sol";

// solhint-disable reason-string

contract SolidlyAdapter is Adapter {
    address public immutable solidlyFactory;
    bool public immutable stable;

    bytes32 internal immutable initCodeHash;

    /**
     * @dev Default Solidly fee is 0.1% = 10bp
     */
    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _solidlyFactoryAddress,
        bytes32 _initCodeHash,
        bool _stable
    ) Adapter(_name, _swapGasEstimate) {
        solidlyFactory = _solidlyFactoryAddress;
        initCodeHash = _initCodeHash;
        stable = _stable;
    }

    function _depositAddress(address _tokenIn, address _tokenOut) internal view override returns (address pair) {
        bytes32 salt = _tokenIn < _tokenOut
            ? keccak256(abi.encodePacked(_tokenIn, _tokenOut, stable))
            : keccak256(abi.encodePacked(_tokenOut, _tokenIn, stable));
        pair = address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", solidlyFactory, salt, initCodeHash)))));
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        address _pair = _depositAddress(_tokenIn, _tokenOut);

        _amountOut = _getPairAmountOut(_pair, _tokenIn, _amountIn);
        require(_amountOut > 0, "Adapter: Insufficient output amount");

        if (_tokenIn < _tokenOut) {
            ISolidlyPair(_pair).swap(0, _amountOut, _to, new bytes(0));
        } else {
            ISolidlyPair(_pair).swap(_amountOut, 0, _to, new bytes(0));
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        address _pair = _depositAddress(_tokenIn, _tokenOut);

        _amountOut = _getPairAmountOut(_pair, _tokenIn, _amountIn);
    }

    function _getPairAmountOut(
        address _pair,
        address _tokenIn,
        uint256 _amountIn
    ) internal view returns (uint256 _amountOut) {
        if (Address.isContract(_pair)) {
            try ISolidlyPair(_pair).getAmountOut(_amountIn, _tokenIn) returns (uint256 amountOut) {
                _amountOut = amountOut;
            } catch {
                this;
            }
        }
    }
}
