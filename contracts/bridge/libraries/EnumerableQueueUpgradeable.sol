// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library EnumerableQueueUpgradeable {
    struct RetryableTx {
        /// @dev epoch time in minutes the tx was stored at. Always non-zero on initialized struct
        uint32 storedAtMin;
        /// @dev bridge calldata for retrying
        bytes toRetry;
    }

    /**
     * @dev New elements are added to the tail of queue:
     *
     *                H=T=0
     *                  v
     * Initial state: EMPTY [head (H) = 0, tail(T) = 0]
     *
     *          H    T
     * add(1): [1]
     *
     *          H         T
     * add(2): [1]<>[2]
     *
     *          H              T
     * add(3): [1]<>[2]<>[3]
     */

    /**
     * @dev Getting arbitrary elements is supported, but not their deletion:
     * Initial state: [1]<>[2]<>[3]
     *  get(key=2) -> [2]: gets data for a given key
     * at(index=0) -> [1]: gets data for a given queue index (queue head index is always 0)
     */

    /**
     * @dev Elements are polled from the head of queue:
     *           H              T
     * State  : [1]<>[2]<>[3]
     *
     *                H         T
     * poll() :      [2]<>[3]
     *
     *                     H    T
     * poll() :           [3]
     */

    struct KappaQueue {
        /// @dev Array of keys for data. Every existing key is unique.
        /// Can't add the same key twice, but it's possible
        /// to add the key again once it is deleted from the Queue.
        mapping(uint256 => bytes32) _keys;
        /// @dev Data map for each key.
        mapping(bytes32 => RetryableTx) _data;
        /// @dev Index of the first Queue key.
        uint128 _head;
        /// @dev Index following the last Queue key, i.e.
        /// index, where newly added key would reside.
        /// _head == _tail => Queue is empty
        uint128 _tail;
    }

    /**
     * @notice Adds [key, value] pair to the `queue`. Will not to anything, if
     * a key already exists in the `queue`.
     *
     * Returns true only if [key, value] was added to the Queue.
     */
    function add(
        KappaQueue storage queue,
        bytes32 key,
        bytes memory value
    ) internal returns (bool) {
        if (contains(queue, key)) {
            // key already exists, don't add anything
            return false;
        }

        queue._keys[queue._tail] = key;
        queue._data[key] = RetryableTx({
            storedAtMin: uint32(block.timestamp / 60),
            toRetry: value
        });

        ++queue._tail;

        return true;
    }

    /**
     * @notice Returns data for N-th element of the Queue:
     * key, value and the time it was stored.
     * @dev All return variables will be zero, if `index >= queue.length()`.
     * `value` will be zero, if `deleteKey(key)` was called previously.
     */
    function at(KappaQueue storage queue, uint256 index)
        internal
        view
        returns (
            bytes32 key,
            bytes memory value,
            uint32 storedAtMin
        )
    {
        key = queue._keys[queue._head + index];
        (value, storedAtMin) = get(queue, key);
    }

    /**
     * @notice Checks whether `key` is present in the Queue.
     */
    function contains(KappaQueue storage queue, bytes32 key)
        internal
        view
        returns (bool)
    {
        return queue._data[key].storedAtMin != 0;
    }

    /**
     * @notice Delete key from the Queue.
     * @dev For gas efficiency we don't use the double-linked queue implementation,
     * allowing to remove an arbitrary element. All we're doing is setting
     * the stored value for the given key to zero.
     * It means, that one should check value obtained by `get(key)` before using it.
     */
    function deleteKey(KappaQueue storage queue, bytes32 key) internal {
        delete queue._data[key];
    }

    /**
     * @notice Checks whether Queue is empty.
     */
    function isEmpty(KappaQueue storage queue) internal view returns (bool) {
        return queue._head == queue._tail;
    }

    /**
     * @notice Gets data associated with the given `key`: value and the time it was stored.
     * @dev All return variables will be zero, if `key` is not added to the Queue.
     * `value` will be zero, if `deleteKey(key)` was called previously.
     */
    function get(KappaQueue storage queue, bytes32 key)
        internal
        view
        returns (bytes memory value, uint32 storedAtMin)
    {
        (value, storedAtMin) = (
            queue._data[key].toRetry,
            queue._data[key].storedAtMin
        );
    }

    /**
     * @notice Returns the number of elements in the Queue.
     */
    function length(KappaQueue storage queue) internal view returns (uint256) {
        // This never underflows
        return queue._tail - queue._head;
    }

    /**
     * @notice Returns data for the first (head) element from
     * the Queue, without removing it.
     * Data: key, value and the time it was stored.
     * @dev All return variables will be zero, Queue is empty.
     * `value` will be zero, if `deleteKey(key)` was called previously.
     */
    function peek(KappaQueue storage queue)
        internal
        view
        returns (
            bytes32 key,
            bytes memory value,
            uint32 storedAtMin
        )
    {
        key = queue._keys[queue._head];
        (value, storedAtMin) = get(queue, key);
    }

    /**
     * @notice Returns data for the first (head) element from
     * the Queue and removes the element from Queue.
     * Data: key, value and the time it was stored.
     * @dev All return variables will be zero, Queue is empty.
     * `value` will be zero, if `deleteKey(key)` was called previously.
     */
    function pop_front(KappaQueue storage queue)
        internal
        returns (
            bytes32 key,
            bytes memory value,
            uint32 storedAtMin
        )
    {
        (uint256 head, uint256 tail) = (queue._head, queue._tail);
        if (head != tail) {
            key = queue._keys[head];
            (value, storedAtMin) = get(queue, key);

            delete queue._keys[head];
            delete queue._data[key];

            ++head;
            if (head == tail) {
                (queue._head, queue._tail) = (0, 0);
            } else {
                queue._head = uint128(head);
            }
        }
    }
}
