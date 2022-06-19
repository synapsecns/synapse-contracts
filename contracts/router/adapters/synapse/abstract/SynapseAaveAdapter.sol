// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {SynapseAdapter} from "./SynapseAdapter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

interface AaveToken is IERC20 {
    function scaledBalanceOf(address user) external view returns (uint256);
}

abstract contract SynapseAaveAdapter is SynapseAdapter {
    ILendingPool public immutable lendingPool;

    /// @dev Tokens are stored internally this way:
    /// [underlyingToken1, underlyingToken2, ..., poolToken1, poolToken2, ...]

    address[] internal underlyingTokens;

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
    ) SynapseAdapter(_name, _swapGasEstimate, _pool) {
        require(_underlyingTokens.length == numTokens, "Wrong tokens amount");
        lendingPool = ILendingPool(_lendingPool);
        underlyingTokens = _underlyingTokens;

        for (uint8 i = 0; i < _underlyingTokens.length; i++) {
            address poolToken = address(poolTokens[i]);
            address underlying = _underlyingTokens[i];
            if (poolToken != underlying) {
                _setInfiniteAllowance(IERC20(underlying), address(lendingPool));
            }
        }
    }

    function _loadToken(uint256 index) internal view override returns (address) {
        if (index < numTokens) return underlyingTokens[index];
        return SynapseAdapter._loadToken(index - numTokens);
    }

    function _getUnderlying(address _token) internal view returns (address) {
        uint256 index = _getIndex(_token);
        if (index < numTokens) return _token;
        return _getToken(index - numTokens);
    }

    function _getWrapped(address _token) internal view returns (address) {
        uint256 index = _getIndex(_token);
        if (index >= numTokens) return _token;
        return _getToken(index + numTokens);
    }

    function _isUnderlying(address _token) internal view returns (bool) {
        return _getIndex(_token) < numTokens;
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        if (_isUnderlying(_tokenIn)) {
            // Approval already granted in _approveIfNeeded()
            _amountIn = _aaveDeposit(_tokenIn, _amountIn);
            // Swap pool can only trade aToken
            _tokenIn = _getWrapped(_tokenIn);
        }
        // check if _tokenOut if underlying
        if (_isUnderlying(_tokenOut)) {
            // User needs to receive underlying token, so we ask the aToken to be sent to this contract
            SynapseAdapter._swap(_amountIn, _tokenIn, _getWrapped(_tokenOut), address(this));
            // Withdraw underlying token directly to user
            _amountOut = _aaveWithdraw(_tokenOut, UINT_MAX, _to);
        } else {
            // User needs to receive pool token, so we can use parent's logic
            _amountOut = SynapseAdapter._swap(_amountIn, _tokenIn, _tokenOut, _to);
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (_isUnderlying(_tokenIn)) {
            // figure out how much aTokens will be transferred
            // as pool contract is comparing balances pre/post transfer
            _amountIn = _calcTransferredIn(_amountIn, _tokenIn);
            // replace _tokenIn with actual pool token
            _tokenIn = _getWrapped(_tokenIn);
        }

        if (_isUnderlying(_tokenOut)) {
            uint256 _index = lendingPool.getReserveNormalizedIncome(_tokenOut);
            // replace _tokenOut with actual pool token
            _tokenOut = _getWrapped(_tokenOut);
            _amountOut = SynapseAdapter._query(_amountIn, _tokenIn, _tokenOut);

            _amountOut = _calcTransferredOut(_amountOut, _index);
        } else {
            _amountOut = SynapseAdapter._query(_amountIn, _tokenIn, _tokenOut);
        }
    }

    // -- AAVE FUNCTIONS

    /// https://github.com/aave/protocol-v2/blob/master/contracts/protocol/libraries/math/WadRayMath.sol
    function _calcTransferredOut(uint256 _amount, uint256 _index) internal pure returns (uint256) {
        uint256 rayDiv = (_amount * RAY + _index / 2) / _index;
        return (rayDiv * _index + HALF_RAY) / RAY;
    }

    function _calcTransferredIn(uint256 _amount, address _token) internal view returns (uint256) {
        uint256 _index = lendingPool.getReserveNormalizedIncome(_token);

        uint256 _delta = (_amount * RAY + _index / 2) / _index;
        uint256 _oldScaledBalance = AaveToken(_getWrapped(_token)).scaledBalanceOf(address(pool));

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
    function _aaveDeposit(address _token, uint256 _amount) internal returns (uint256) {
        lendingPool.deposit(_token, _amount, address(this), 0);
        return IERC20(_getWrapped(_token)).balanceOf(address(this));
    }

    /**
     * @notice Withdraw token from Aave and send underlying token to user
     *
     * @dev Chad (lendingPool) doesn't need your approval to spend your aToken.
     * 		Use [_to = address(this);] if token needs further (un)wrapping
     *      Use [_amount = UINT_MAX] to withdraw all aToken balance
     *
     * @param _token underlying token to withdraw
     * @param _amount amount of token to withdraw
     * @param _to address that will receive underlying token
     *
     * @return amount of underlying token withdrawn
     */
    function _aaveWithdraw(
        address _token,
        uint256 _amount,
        address _to
    ) internal returns (uint256) {
        return lendingPool.withdraw(_token, _amount, _to);
    }
}
