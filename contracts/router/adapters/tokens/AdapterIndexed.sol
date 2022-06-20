// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterBase} from "../AdapterBase.sol";

abstract contract AdapterIndexed is AdapterBase {
    function _checkTokens(address tokenIn, address tokenOut) internal view virtual override returns (bool) {
        return _checkToken(tokenIn) && _checkToken(tokenOut);
    }

    /// @dev Checks if a token is supported by the Adapter
    function _checkToken(address token) internal view virtual returns (bool);

    /// @dev Gets a token's index given its address. It is assumed this method
    /// is heavily optimized by doing precalculations in the constructor.
    function _getIndex(address _token) internal view virtual returns (uint256);

    /// @dev Gets a token address given its index. It is assumed this method
    /// is heavily optimized by doing precalculations in the constructor.
    function _getToken(uint256 _index) internal view virtual returns (address);

    /// @dev Loads a token address given its index. It is assumed this method
    /// is using external calls and should be used only in the constructor.
    function _loadToken(uint256 _index) internal view virtual returns (address);
}
