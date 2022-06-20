// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterIndexed} from "./AdapterIndexed.sol";

/// @dev This adapter supports exactly three tokens.
abstract contract AdapterThree is AdapterIndexed {
    address internal immutable tokenZero;
    address internal immutable tokenOne;
    address internal immutable tokenTwo;

    constructor() {
        tokenZero = _loadToken(0);
        tokenOne = _loadToken(1);
        tokenTwo = _loadToken(2);
    }

    function _getToken(uint256 index) internal view virtual override returns (address) {
        if (index == 0) return tokenZero;
        if (index == 1) return tokenOne;
        if (index == 2) return tokenTwo;
        revert("Index out of bounds");
    }

    function _getIndex(address token) internal view virtual override returns (uint256) {
        if (token == tokenZero) return 0;
        if (token == tokenOne) return 1;
        if (token == tokenTwo) return 2;
        revert("Unknown token");
    }

    function _checkToken(address token) internal view virtual override returns (bool) {
        return token == tokenZero || token == tokenOne || token == tokenTwo;
    }
}
