// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IRouter} from "./interfaces/IRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {BasicRouter} from "./BasicRouter.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts-4.4.2/security/ReentrancyGuard.sol";

// solhint-disable reason-string

contract Router is ReentrancyGuard, BasicRouter, IRouter {
    using SafeERC20 for IERC20;

    constructor(address payable _wgas) BasicRouter(_wgas) {
        this;
    }

    // -- SWAPPERS [single chain swaps] --

    function swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _amountOut) {
        _amountOut = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            _to
        );
    }

    function swapFromGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external payable returns (uint256 _amountOut) {
        require(msg.value == _amountIn, "Router: incorrect amount of GAS");
        require(_path[0] == WGAS, "Router: Path needs to begin with WGAS");
        _wrap(_amountIn);
        // WGAS tokens need to be sent from this contract
        _amountOut = _selfSwap(_amountIn, _minAmountOut, _path, _adapters, _to);
    }

    function swapToGAS(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) external returns (uint256 _amountOut) {
        require(
            _path[_path.length - 1] == WGAS,
            "Router: Path needs to end with WGAS"
        );
        // This contract needs to receive WGAS in order to unwrap it
        _amountOut = _swap(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            msg.sender,
            address(this)
        );
        // this will unwrap WGAS and return GAS
        // reentrancy not an issue here, as all work is done
        _returnTokensTo(WGAS, _amountOut, _to);
    }

    // -- INTERNAL SWAP FUNCTIONS --

    /// @dev All internal swap functions have a reentrancy guard

    /**
     * @notice Pull tokens from user and perform a series of swaps
     * @dev Use _selfSwap if tokens are already in the contract
     *      Don't do this: _from = address(this);
     * @return _amountOut Final amount of tokens swapped
     */
    function _swap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _from,
        address _to
    ) internal nonReentrant returns (uint256 _amountOut) {
        IERC20(_path[0]).safeTransferFrom(
            _from,
            _getDepositAddress(_path, _adapters, 0),
            _amountIn
        );

        _amountOut = _doChainedSwaps(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            _to
        );
    }

    /**
     * @notice Perform a series of swaps, assuming the starting tokens
     *         are already deposited in this contract
     * @return _amountOut Final amount of tokens swapped
     */
    function _selfSwap(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) internal nonReentrant returns (uint256 _amountOut) {
        IERC20(_path[0]).safeTransfer(
            _getDepositAddress(_path, _adapters, 0),
            _amountIn
        );

        _amountOut = _doChainedSwaps(
            _amountIn,
            _minAmountOut,
            _path,
            _adapters,
            _to
        );
    }

    /**
     * @notice Perform a series of swaps, assuming the starting tokens
     *         have already been deposited in the first adapter
     * @return _amountOut Final amount of tokens swapped
     */
    function _doChainedSwaps(
        uint256 _amountIn,
        uint256 _minAmountOut,
        address[] calldata _path,
        address[] calldata _adapters,
        address _to
    ) internal returns (uint256 _amountOut) {
        require(
            _path.length == _adapters.length + 1,
            "Router: wrong amount of adapters/tokens"
        );
        require(_to != address(0), "Router: _to cannot be zero address");
        for (uint8 i = 0; i < _adapters.length; ++i) {
            require(isTrustedAdapter[_adapters[i]], "Router: unknown adapter");
        }
        _amountOut = _amountIn;
        for (uint8 i = 0; i < _adapters.length; ++i) {
            address _targetAddress = i < _adapters.length - 1
                ? _getDepositAddress(_path, _adapters, i + 1)
                : _to;
            _amountOut = IAdapter(_adapters[i]).swap(
                _amountOut,
                _path[i],
                _path[i + 1],
                _targetAddress
            );
        }
        require(
            _amountOut >= _minAmountOut,
            "Router: Insufficient output amount"
        );
        emit Swap(_path[0], _path[_path.length - 1], _amountIn, _amountOut);
    }

    // -- INTERNAL HELPERS

    /**
     * @notice Get selected adapter's deposit address
     *
     * @dev Return value of address(0) means that
     *      adapter doesn't support this pair of tokens
     */
    function _getDepositAddress(
        address[] calldata _path,
        address[] calldata _adapters,
        uint8 _index
    ) internal view returns (address _depositAddress) {
        _depositAddress = IAdapter(_adapters[_index]).depositAddress(
            _path[_index],
            _path[_index + 1]
        );
        require(_depositAddress != address(0), "Adapter: unknown tokens");
    }
}
