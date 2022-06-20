// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Adapter} from "../Adapter.sol";
import {AdapterUniversal} from "../tokens/AdapterUniversal.sol";

import {IGmxReader} from "./interfaces/IGmxReader.sol";
import {IGmxVault} from "./interfaces/IGmxVault.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

contract GmxAdapter is Adapter, AdapterUniversal {
    IGmxVault public immutable vault;
    IGmxReader public immutable reader;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _vault,
        address _reader
    ) Adapter(_name, _swapGasEstimate) {
        vault = IGmxVault(_vault);
        reader = IGmxReader(_reader);
    }

    function _depositAddress(address, address) internal view override returns (address) {
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
        try reader.getMaxAmountIn(address(vault), _tokenIn, _tokenOut) returns (uint256 maxAmountIn) {
            if (_amountIn > maxAmountIn) {
                return 0;
            }
        } catch {
            return 0;
        }

        try reader.getAmountOut(address(vault), _tokenIn, _tokenOut, _amountIn) returns (
            uint256 amountOutAfterFees,
            uint256
        ) {
            _amountOut = amountOutAfterFees;
        } catch {
            return 0;
        }
    }
}
