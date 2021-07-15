// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

/**
 * @title EnumerableStringMap
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * this isn't a terribly gas efficient implementation because it emphasizes usability over gas efficiency
 * by allowing arbitrary length string memorys. If Gettetrs/Setters are going to be used frequently in contracts
 * consider using the OpenZeppeling Bytes32 implementation
 *
 * this also differs from the OpenZeppelin implementation by keccac256 hashing the string memorys
 * so we can use enumerable bytes32 set
 */
library EnumerableStringMap {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct Map {
        // Storage of keys as a set
        EnumerableSet.Bytes32Set _keys;
        // Mapping of keys to resulting values to allow key lookup in the set
        mapping(bytes32 => string) _hashKeyMap;
        // values
        mapping(bytes32 => string) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function _set(
        Map storage map,
        string memory key,
        string memory value
    ) private returns (bool) {
        bytes32 keyHash = keccak256(abi.encodePacked(key));
        map._values[keyHash] = value;
        map._hashKeyMap[keyHash] = key;
        return map._keys.add(keyHash);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function _remove(Map storage map, bytes32 keyHash) private returns (bool) {
        delete map._values[keyHash];
        delete map._hashKeyMap[keyHash];
        return map._keys.remove(keyHash);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function _contains(Map storage map, bytes32 keyHash) private view returns (bool) {
        return map._keys.contains(keyHash);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function _length(Map storage map) private view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Map storage map, uint256 index) private view returns (string memory, string memory) {
        bytes32 keyHash = map._keys.at(index);
        return (map._hashKeyMap[keyHash], map._values[keyHash]);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     */
    function _tryGet(Map storage map, bytes32 keyHash) private view returns (bool, string memory) {
        string memory value = map._values[keyHash];
        if (keccak256(bytes(value)) == keccak256(bytes(""))) {
            return (_contains(map, keyHash), "");
        } else {
            return (true, value);
        }
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function _get(Map storage map, bytes32 keyHash) private view returns (string memory) {
        string memory value = map._values[keyHash];
        require(_contains(map, keyHash), "EnumerableMap: nonexistent key");
        return value;
    }

    // StringToStringMap
    struct StringToStringMap {
        Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        StringToStringMap storage map,
        string memory key,
        string memory value
    ) internal returns (bool) {
        return _set(map._inner, key, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(StringToStringMap storage map, string memory key) internal returns (bool) {
        return _remove(map._inner, keccak256(abi.encodePacked(key)));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(StringToStringMap storage map, string memory key) internal view returns (bool) {
        return _contains(map._inner, keccak256(abi.encodePacked(key)));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(StringToStringMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(StringToStringMap storage map, uint256 index) internal view returns (string memory, string memory) {
        return _at(map._inner, index);
    }

    /**
     * @dev Tries to returns the value associated with `key`.  O(1).
     * Does not revert if `key` is not in the map.
     *
     * _Available since v3.4._
     */
    function tryGet(StringToStringMap storage map, uint256 key) internal view returns (bool, string memory) {
        (bool success, string memory value) = _tryGet(map._inner, bytes32(key));
        return (success, value);
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(StringToStringMap storage map, string memory key) internal view returns (string memory) {
        return _get(map._inner, keccak256(abi.encodePacked(key)));
    }
}