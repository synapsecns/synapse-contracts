// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {GMXV1Module} from "./GMXV1Module.sol";

contract GMXV1StableAvalancheModule is GMXV1Module {
    /// @dev order of tokens is same as in GMX v1 vault
    address public constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    constructor(address _router, address _reader) GMXV1Module(_router, _reader) {}

    function _isSupported(address token) internal view virtual override returns (bool) {
        return (token == USDC_E || token == USDC);
    }
}
