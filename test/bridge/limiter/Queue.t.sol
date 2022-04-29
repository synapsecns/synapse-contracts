// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {EnumerableQueueUpgradeable} from "src-bridge/libraries/EnumerableQueueUpgradeable.sol";

contract QueueTest is Test {
    using EnumerableQueueUpgradeable for EnumerableQueueUpgradeable.KappaQueue;

    EnumerableQueueUpgradeable.KappaQueue internal queue;

    uint256 internal constant AMOUNT = 5;

    function setUp() public {
        vm.warp(14000000);
    }

    // Add to Full (F) queue, then poll all
    function testAdd1F(bytes32 key) public {
        vm.assume(key != bytes32(0));
        _add(key, 4 * AMOUNT);
        _poll_front(4 * AMOUNT);
    }

    // Add to queue, then poll until it's empty (E) two times
    function testAdd2E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 2; ++i) {
            key = _add(key, 2 * AMOUNT);
            _poll_front(2 * AMOUNT);
        }
    }

    // Add to queue, then poll until it's empty (E) three times
    function testAdd3E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 3; ++i) {
            uint256 amount = i == 0 ? 2 * AMOUNT : AMOUNT;
            key = _add(key, amount);
            _poll_front(amount);
        }
    }

    // Add to queue, then poll until it's empty (E) four times
    function testAdd4E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 4; ++i) {
            key = _add(key, AMOUNT);
            _poll_front(AMOUNT);
        }
    }

    function testUsage(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 4; ++i) {
            key = _addCheck(key, AMOUNT);
            _pollCheck(AMOUNT);
        }
    }

    function _add(bytes32 key, uint256 amount) internal returns (bytes32) {
        for (uint256 i = 0; i < amount; i++) {
            bytes memory value = abi.encode(key);
            assertTrue(queue.add(key, value));
            key = keccak256(value);
        }
        return key;
    }

    function _addCheck(bytes32 key, uint256 amount) internal returns (bytes32) {
        for (uint256 i = 0; i < amount; i++) {
            assertTrue(!queue.contains(key), "Key already present");
            bytes memory value = abi.encode(key);
            assertTrue(queue.add(key, value), "Key not added");
            assertTrue(queue.contains(key), "New key not found");

            (bytes memory _value, ) = queue.get(key);
            key = keccak256(value);
            assertTrue(key == keccak256(_value), "Value doesn't match");
        }
        return key;
    }

    function _poll_front(uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            queue.pop_front();
        }
    }

    function _pollCheck(uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            (bytes32 key, bytes memory value, ) = queue.pop_front();

            assertTrue(!queue.contains(key), "Key not deleted");
            assertTrue(
                keccak256(abi.encode(key)) == keccak256(value),
                "Wrong value"
            );

            (value, ) = queue.get(key);
            assertTrue(value.length == 0, "Data remains after deletion");
        }
    }
}
