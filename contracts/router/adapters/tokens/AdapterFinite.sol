// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterBase} from "../AdapterBase.sol";

abstract contract AdapterFinite is AdapterBase {
    function _checkTokens(address tokenIn, address tokenOut) internal view virtual override returns (bool) {
        return _checkToken(tokenIn) && _checkToken(tokenOut);
    }
}
