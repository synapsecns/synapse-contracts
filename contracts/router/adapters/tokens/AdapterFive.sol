// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterIndexed} from "./AdapterIndexed.sol";

/// @dev This adapter supports exactly five tokens.
abstract contract AdapterFive is AdapterIndexed {
    address internal immutable tokenZero;
    address internal immutable tokenOne;
    address internal immutable tokenTwo;
    address internal immutable tokenThree;
    address internal immutable tokenFour;

    constructor() {
        tokenZero = _loadToken(0);
        tokenOne = _loadToken(1);
        tokenTwo = _loadToken(2);
        tokenThree = _loadToken(3);
        tokenFour = _loadToken(4);
    }

    function _getToken(uint256 index) internal view virtual override returns (address) {
        if (index == 0) return tokenZero;
        if (index == 1) return tokenOne;
        if (index == 2) return tokenTwo;
        if (index == 3) return tokenThree;
        if (index == 4) return tokenFour;
        revert("Index out of bounds");
    }

    function _getIndex(address token) internal view virtual override returns (uint256) {
        if (token == tokenZero) return 0;
        if (token == tokenOne) return 1;
        if (token == tokenTwo) return 2;
        if (token == tokenThree) return 3;
        if (token == tokenFour) return 4;
        revert("Unknown token");
    }

    function _checkToken(address token) internal view virtual override returns (bool) {
        return
            token == tokenZero || token == tokenOne || token == tokenTwo || token == tokenThree || token == tokenFour;
    }
}
