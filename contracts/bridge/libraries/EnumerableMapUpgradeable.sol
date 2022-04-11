// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.6.0-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * this extends https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.6.0-rc.0/contracts/utils/structs/EnumerableMap.sol
 * wth a bytes32 to bytes map
*/

library EnumerableMapUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    /**
    * Contains a tx that should be retried and the timestamp it was stored at
    */
    struct RetryableTx {
        // @dev epoch time in minutes the tx was stored at. Always non-zero on initialized struct
        uint32 storedAtMin;
        bytes toRetry;
    }

    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct Bytes32ToStructMap {
        // Storage of keys
        EnumerableSetUpgradeable.Bytes32Set _keys;
        mapping(bytes32 => RetryableTx) _values;
    }


    /**
    * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        Bytes32ToStructMap storage map,
        bytes32 key,
        bytes memory value
    ) internal returns (bool) {
        RetryableTx memory retryable = RetryableTx({
            storedAtMin: uint32(block.timestamp / 60),
            toRetry: value
        });

        map._values[key] = retryable;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToStructMap storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToStructMap storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function length(Bytes32ToStructMap storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map and the time it was stored.
     * O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToStructMap storage map, uint256 index) internal view returns (bytes32, bytes memory, uint32) {
        bytes32 key = map._keys.at(index);
        RetryableTx memory retryable = map._values[key];
        return (key, retryable.toRetry, retryable.storedAtMin);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToStructMap storage map, bytes32 key) internal view returns (bool, bytes memory, uint32) {
        RetryableTx memory value = map._values[key];
        if (value.storedAtMin == 0) {
            return (contains(map, key), bytes(""), 0);
        } else {
            return (true, value.toRetry, value.storedAtMin);
        }
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToStructMap storage map, bytes32 key) internal view returns (bytes memory, uint32) {
        RetryableTx memory value = map._values[key];
        require(value.storedAtMin != 0 || contains(map, key), "EnumerableMap: nonexistent key");
        return (value.toRetry, value.storedAtMin);
    }

    /**
     * @dev Same as {_get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {_tryGet}.
     */
    function get(
        Bytes32ToStructMap storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (bytes memory, uint32) {
        RetryableTx memory value = map._values[key];
        require(value.storedAtMin != 0 || contains(map, key), errorMessage);
        return (value.toRetry, value.storedAtMin);
    }
}