// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {BridgeToken} from "./Structs.sol";

/// @notice Arrays library offers helper functions for working with arrays and array of arrays
library Arrays {
    error ArrayLengthInvalid(uint256 count);

    /// @notice Flattens out a list of lists of bridge tokens into a list of bridge tokens
    /// @param unflattened The list of lists of bridge tokens
    /// @param count The total number of bridge tokens in unflattened
    /// @return flattened The flattened list of bridge tokens
    function flatten(BridgeToken[][] memory unflattened, uint256 count)
        internal
        pure
        returns (BridgeToken[] memory flattened)
    {
        flattened = new BridgeToken[](count);

        uint256 k;
        for (uint256 i = 0; i < unflattened.length; ++i) {
            for (uint256 j = 0; j < unflattened[i].length; ++j) {
                flattened[k] = unflattened[i][j];
                k++;
            }
        }

        if (k != count) revert ArrayLengthInvalid(k); // @dev should never happen in practice w router
    }

    /// @notice Flattens out a list of lists of addresses into a list of addresses
    /// @param unflattened The list of lists of addresses
    /// @param count The total number of addresses in unflattened
    /// @return flattened The flattened list of addresses
    function flatten(address[][] memory unflattened, uint256 count) internal pure returns (address[] memory flattened) {
        flattened = new address[](count);

        uint256 k;
        for (uint256 i = 0; i < unflattened.length; ++i) {
            for (uint256 j = 0; j < unflattened[i].length; ++j) {
                flattened[k] = unflattened[i][j];
                k++;
            }
        }

        if (k != count) revert ArrayLengthInvalid(k); // @dev should never happen in practice w router
    }

    /// @notice Filters out duplicates and zero addresses from given list of addresses
    /// @dev Removes zero addresses from list
    /// @param unfiltered The list of addresses with duplicates
    /// @return filtered The list of addresses without duplicates
    function unique(address[] memory unfiltered) internal pure returns (address[] memory filtered) {
        address[] memory intermediate = new address[](unfiltered.length);

        // add unique elements to intermediate
        uint256 count;
        for (uint256 i = 0; i < unfiltered.length; ++i) {
            address el = unfiltered[i];
            if (!contains(intermediate, el)) {
                intermediate[count] = el;
                count++;
            }
        }

        // remove the zero elements at the end if any duplicates
        filtered = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            filtered[i] = intermediate[i];
        }
    }

    /// @notice Whether given element is in the list of addresses
    /// @param l The list of addresses
    /// @param el The element to search for
    /// @return does If given list does contain element
    function contains(address[] memory l, address el) internal pure returns (bool does) {
        for (uint256 j = 0; j < l.length; ++j) {
            does = (el == l[j]);
            if (does) break;
        }
    }

    /// @notice Appends a new element to the end of the list of addresses
    /// @param l The list of addresses
    /// @param el The element to append
    /// @param r The new list of addresses with appended element
    function append(address[] memory l, address el) internal pure returns (address[] memory r) {
        r = new address[](l.length + 1);
        for (uint256 i = 0; i < l.length; i++) r[i] = l[i];
        r[r.length - 1] = el;
    }
}
