// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterBase} from "../AdapterBase.sol";

/// @dev This adapter supports arbitrary amount of tokens.
abstract contract AdapterInfinite is AdapterBase {
    function _loadToken(uint256) internal view virtual override returns (address) {
        revert("No token indexing");
    }

    function _getToken(uint256) internal view virtual override returns (address) {
        revert("No token indexing");
    }

    function _getIndex(address) internal view virtual override returns (uint256) {
        revert("No token indexing");
    }

    function _checkToken(address) internal view virtual override returns (bool) {
        return true;
    }

    /// @dev It's assumed that the possibility of the swap between two tokens is checked
    // / either in adapter implementation elsewhere, or in the underneath pool itself.
    function _checkTokens(address, address) internal view virtual override returns (bool) {
        return true;
    }
}
