// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISynapse} from "../../interfaces/ISynapse.sol";
import {Adapter} from "../../Adapter.sol";
import {SwapAddCalculator} from "../../helper/SwapAddCalculator.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

//solhint-disable not-rely-on-time

contract SynapseBasePoolAdapter is SwapAddCalculator, Adapter {
    mapping(address => bool) public isPoolToken;
    mapping(address => uint8) public tokenIndex;

    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate
    ) SwapAddCalculator(ISynapse(_pool)) Adapter(_name, _swapGasEstimate) {
        isPoolToken[address(lpToken)] = true;
        tokenIndex[address(lpToken)] = uint8(numTokens);
    }

    function _addPoolToken(IERC20 token, uint8 index)
        internal
        virtual
        override
    {
        SwapAddCalculator._addPoolToken(token, index);
        isPoolToken[address(token)] = true;
        tokenIndex[address(token)] = index;
    }

    function _approveIfNeeded(address _tokenIn, uint256 _amount)
        internal
        virtual
        override
    {
        _checkAllowance(IERC20(_tokenIn), _amount, address(pool));
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
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        require(_amountIn != 0, "Insufficient input amount");
        require(_tokenIn != _tokenOut, "Tokens must differ");
        require(
            isPoolToken[_tokenIn] && isPoolToken[_tokenOut],
            "Unknown tokens"
        );

        if (
            tokenIndex[_tokenIn] != numTokens &&
            tokenIndex[_tokenOut] != numTokens
        ) {
            // swap tokens
            _amountOut = pool.swap(
                tokenIndex[_tokenIn],
                tokenIndex[_tokenOut],
                _amountIn,
                0,
                block.timestamp
            );
        } else {
            if (tokenIndex[_tokenOut] == numTokens) {
                // add liquidity
                uint256[] memory amounts = new uint256[](numTokens);
                amounts[(tokenIndex[_tokenIn])] = _amountIn;

                _amountOut = pool.addLiquidity(amounts, 0, block.timestamp);
            } else {
                // remove liquidity
                _amountOut = pool.removeLiquidityOneToken(
                    _amountIn,
                    tokenIndex[_tokenOut],
                    0,
                    block.timestamp
                );
            }
        }
        _returnTo(_tokenOut, _amountOut, _to);
    }

    function _checkTokens(address _tokenIn, address _tokenOut)
    internal
    view
    virtual
    override
    returns (bool){
        return true;
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        if (
            _amountIn == 0 ||
            _tokenIn == _tokenOut ||
            !isPoolToken[_tokenIn] ||
            !isPoolToken[_tokenOut] ||
            pool.paused()
        ) {
            return 0;
        }
        if (
            tokenIndex[_tokenIn] != numTokens &&
            tokenIndex[_tokenOut] != numTokens
        ) {
            try
                pool.calculateSwap(
                    tokenIndex[_tokenIn],
                    tokenIndex[_tokenOut],
                    _amountIn
                )
            returns (uint256 amountOut) {
                _amountOut = amountOut;
            } catch {
                return 0;
            }
        } else {
            if (tokenIndex[_tokenOut] == numTokens) {
                // add liquidity
                uint256[] memory _amounts = new uint256[](numTokens);
                _amounts[tokenIndex[_tokenIn]] = _amountIn;

                _amountOut = calculateAddLiquidity(_amounts);
            } else if (tokenIndex[_tokenIn] == numTokens) {
                // remove liquidity
                try
                    pool.calculateRemoveLiquidityOneToken(
                        _amountIn,
                        tokenIndex[_tokenOut]
                    )
                returns (uint256 amountOut) {
                    _amountOut = amountOut;
                } catch {
                    return 0;
                }
            }
        }
    }
}
