// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library KappaMapUpgradeable {
    struct RetryableTx {
        /// @dev epoch time in minutes the tx was stored at. Always non-zero on initialized struct
        uint32 storedAtMin;
        /// @dev bridge calldata for retrying
        bytes toRetry;
    }

    struct KappaMap {
        mapping(bytes32 => RetryableTx) _data;
    }

    /**
     * @notice Adds [key, value] pair to the `map`. Will not to anything, if
     * a key already exists in the `map`.
     *
     * Returns true only if [key, value] was added to the Queue.
     */
    function add(
        KappaMap storage map,
        bytes32 key,
        bytes memory value
    ) internal returns (bool) {
        if (contains(map, key)) {
            // key already exists, don't add anything
            return false;
        }

        map._data[key] = RetryableTx({
            storedAtMin: uint32(block.timestamp / 60),
            toRetry: value
        });

        return true;
    }

    /**
     * @notice Checks whether `key` is present in the Queue.
     */
    function contains(KappaMap storage map, bytes32 key)
        internal
        view
        returns (bool)
    {
        return map._data[key].storedAtMin != 0;
    }

    /**
     * @notice Gets data associated with the given `key`: value and the time it was stored,
     * without removing `key` from the Map.
     * @dev All return variables will be zero, if `key` is not added to the Map.
     */
    function get(KappaMap storage map, bytes32 key)
        internal
        view
        returns (bytes memory value, uint32 storedAtMin)
    {
        (value, storedAtMin) = (
            map._data[key].toRetry,
            map._data[key].storedAtMin
        );
    }

    /**
     * @notice Gets data associated with the given `key`: value and the time it was stored,
     * while removing `key` from the Map.
     * @dev All return variables will be zero, if `key` is not added to the Map.
     */
    function remove(KappaMap storage map, bytes32 key)
        internal
        returns (bytes memory value, uint32 storedAtMin)
    {
        (value, storedAtMin) = (
            map._data[key].toRetry,
            map._data[key].storedAtMin
        );
        delete map._data[key];
    }
}
