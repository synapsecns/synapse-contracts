// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {BridgeToken} from "./Structs.sol";

/// @notice Arrays library offers helper functions for working with arrays and array of arrays
library Arrays {
    error ArrayLengthInvalid(uint256 count);

    // TODO: test
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

    // TODO: test
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

    // TODO: test
    /// @notice Filters out duplicates from given list of addresses
    /// @param unfiltered The list of addresses with duplicates
    /// @return filtered The list of addresses without duplicates
    function unique(address[] memory unfiltered) internal pure returns (address[] memory filtered) {
        address[] memory intermediate = new address[](unfiltered.length);
        uint256 count;
        for (uint256 i = 0; i < unfiltered.length; ++i) {
            address el = unfiltered[i];

            // check whether el already in intermediate (unique elements)
            bool contains;
            for (uint256 j = 0; j < intermediate.length; ++j) {
                contains = (el == intermediate[j]);
                if (contains) break;
            }

            if (!contains) {
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
}
