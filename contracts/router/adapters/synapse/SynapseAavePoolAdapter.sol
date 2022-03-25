// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {ISynapse} from "../../interfaces/ISynapse.sol";
import {SynapseBasePoolAdapter} from "./SynapseBasePoolAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

interface AaveToken is IERC20 {
    function scaledBalanceOf(address user) external view returns (uint256);
}

contract SynapseAavePoolAdapter is SynapseBasePoolAdapter {
    ILendingPool public immutable lendingPool;

    mapping(address => address) public aaveToken;
    mapping(address => bool) public isUnderlying;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = RAY / 2;

    /**
     * @param _name Adapter name
     * @param _pool Pool address
     * @param _swapGasEstimate Estimated gas usage for this.swap()
     * @param _lendingPool Aave lending pool address
     * @param _underlyingTokens underlying pool tokens, that will be traded
     */
    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate,
        address _lendingPool,
        address[] memory _underlyingTokens
    ) SynapseBasePoolAdapter(_name, _pool, _swapGasEstimate) {
        require(_underlyingTokens.length == numTokens, "Wrong tokens amount");
        lendingPool = ILendingPool(_lendingPool);
        for (uint8 i = 0; i < _underlyingTokens.length; i++) {
            address _poolToken = address(poolTokens[i]);
            if (_poolToken != _underlyingTokens[i]) {
                aaveToken[_underlyingTokens[i]] = _poolToken;
                isUnderlying[_underlyingTokens[i]] = true;
            }
        }
    }

    function _approveIfNeeded(address _tokenIn, uint256 _amount)
        internal
        virtual
        override
    {
        if (isUnderlying[_tokenIn]) {
            // Lending Pool needs to have approval to spend underlying
            _checkAllowance(IERC20(_tokenIn), _amount, address(lendingPool));
            // Swap pool needs to have approval to spend aToken
            _tokenIn = aaveToken[_tokenIn];
        }
        SynapseBasePoolAdapter._approveIfNeeded(_tokenIn, _amount);
    }

    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        if (isUnderlying[_tokenIn]) {
            // Approval already granted in _approveIfNeeded()
            _amountIn = _aaveDeposit(_tokenIn, _amountIn);
            // Swap pool can only trade aToken
            _tokenIn = aaveToken[_tokenIn];
        }
        if (isUnderlying[_tokenOut]) {
            // User needs to receive underlying token, so we ask the aToken to be sent to this contract
            SynapseBasePoolAdapter._swap(
                _amountIn,
                _tokenIn,
                aaveToken[_tokenOut],
                address(this)
            );
            // Withdraw underlying token directly to user
            _amountOut = _aaveWithdraw(_tokenOut, UINT_MAX, _to);
        } else {
            // User needs to receive pool token, so we can use parent's logic
            _amountOut = SynapseBasePoolAdapter._swap(
                _amountIn,
                _tokenIn,
                _tokenOut,
                _to
            );
        }
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (isUnderlying[_tokenIn]) {
            // figure out how much aTokens will be transferred
            // as pool contract is comparing balances pre/post transfer
            _amountIn = _calcTransferredIn(_amountIn, _tokenIn);
            // replace _tokenIn with actual pool token
            _tokenIn = aaveToken[_tokenIn];
        }

        if (isUnderlying[_tokenOut]) {
            uint256 _index = lendingPool.getReserveNormalizedIncome(_tokenOut);
            // replace _tokenOut with actual pool token
            _tokenOut = aaveToken[_tokenOut];
            _amountOut = SynapseBasePoolAdapter._query(
                _amountIn,
                _tokenIn,
                _tokenOut
            );

            _amountOut = _calcTransferredOut(_amountOut, _index);
        } else {
            _amountOut = SynapseBasePoolAdapter._query(
                _amountIn,
                _tokenIn,
                _tokenOut
            );
        }
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

    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        // Swaps are supported between both pool and underlying tokens
        return
            (isPoolToken[_tokenIn] || isUnderlying[_tokenIn]) &&
            (isPoolToken[_tokenOut] || isUnderlying[_tokenOut]);
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
