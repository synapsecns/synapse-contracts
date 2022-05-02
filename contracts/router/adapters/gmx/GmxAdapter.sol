// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../../Adapter.sol";

import {IGmxReader} from "../interfaces/IGmxReader.sol";
import {IGmxVault} from "../interfaces/IGmxVault.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";

contract GmxAdapter is Adapter {
    IGmxVault public immutable vault;
    IGmxReader public immutable reader;

    mapping(address => bool) public isPoolToken;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _vault,
        address _reader
    ) Adapter(_name, _swapGasEstimate) {
        vault = IGmxVault(_vault);
        reader = IGmxReader(_reader);
        _setPoolTokens();
    }

    function _setPoolTokens() internal {
        uint256 _amount = vault.allWhitelistedTokensLength();
        for (uint256 index = 0; index < _amount; ++index) {
            address _token = vault.allWhitelistedTokens(index);
            isPoolToken[_token] = true;
        }
    }

    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return isPoolToken[_tokenIn] && isPoolToken[_tokenOut];
    }

    function _depositAddress(address, address)
        internal
        view
        override
        returns (address)
    {
        return address(vault);
    }

    function _swap(
        uint256,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual override returns (uint256 _amountOut) {
        _amountOut = vault.swap(_tokenIn, _tokenOut, _to);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual override returns (uint256 _amountOut) {
        try reader.getMaxAmountIn(address(vault), _tokenIn, _tokenOut) returns (
            uint256 maxAmountIn
        ) {
            if (_amountIn > maxAmountIn) {
                return 0;
            }
        } catch {
            return 0;
        }

        try
            reader.getAmountOut(address(vault), _tokenIn, _tokenOut, _amountIn)
        returns (uint256 amountOutAfterFees, uint256) {
            _amountOut = amountOutAfterFees;
        } catch {
            return 0;
        }
    }
}
