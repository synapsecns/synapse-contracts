// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../Adapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";

import {SafeCast} from "@openzeppelin/contracts-4.4.2/utils/math/SafeCast.sol";

contract CurveBasePoolAdapter is Adapter {
    ICurvePool public pool;

    mapping(address => bool) public isPoolToken;
    mapping(address => int128) public tokenIndex;

    constructor(
        string memory _name,
        address _pool,
        uint256 _swapGasEstimate
    ) Adapter(_name, _swapGasEstimate) {
        pool = ICurvePool(_pool);
        _setPoolTokens();
    }

    function _setPoolTokens() internal virtual {
        for (uint8 i = 0; true; i++) {
            try pool.coins(i) returns (address _tokenAddress) {
                _addPoolToken(_tokenAddress, i);
            } catch {
                break;
            }
        }
    }

    function _addPoolToken(address _tokenAddress, uint8 _index)
        internal
        virtual
    {
        isPoolToken[_tokenAddress] = true;
        tokenIndex[_tokenAddress] = SafeCast.toInt128(
            SafeCast.toInt256(_index)
        );
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
        virtual
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
        require(_amountIn != 0, "Curve: Insufficient input amount");
        require(
            isPoolToken[_tokenIn] && isPoolToken[_tokenOut],
            "Curve: unknown tokens"
        );
        pool.exchange(
            tokenIndex[_tokenIn],
            tokenIndex[_tokenOut],
            _amountIn,
            0
        );
        // Imagine not returning amount of swapped tokens
        _amountOut = IERC20(_tokenOut).balanceOf(address(this));
        _returnTo(_tokenOut, _amountOut, _to);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256) {
        if (
            _amountIn == 0 || !isPoolToken[_tokenIn] || !isPoolToken[_tokenOut]
        ) {
            return 0;
        }
        // -1 to account for rounding errors.
        // This will underquote by 1 wei sometimes, but that's life
        return
            pool.get_dy(
                tokenIndex[_tokenIn],
                tokenIndex[_tokenOut],
                _amountIn
            ) - 1;
    }
}
