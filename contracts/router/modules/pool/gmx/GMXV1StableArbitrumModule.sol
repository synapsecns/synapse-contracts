// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {GMXV1Module} from "./GMXV1Module.sol";

contract GMXV1StableArbitrumModule is GMXV1Module {
    /// @dev order of tokens is same as in GMX v1 vault
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    constructor(address _router, address _reader) GMXV1Module(_router, _reader) {}

    function _isSupported(address token) internal view virtual override returns (bool) {
        return (token == USDC_E || token == USDT || token == FRAX || token == DAI || token == USDC);
    }
}
