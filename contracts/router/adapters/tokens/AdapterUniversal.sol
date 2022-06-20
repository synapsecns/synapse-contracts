// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AdapterBase} from "../AdapterBase.sol";

/// @dev This adapter supports arbitrary amount of tokens.
abstract contract AdapterUniversal is AdapterBase {
    /// @dev It's assumed that the possibility of the swap between two tokens is checked
    /// either in adapter implementation elsewhere, or in the underneath pool itself.
    function _checkTokens(address, address) internal view virtual override returns (bool) {
        return true;
    }
}
