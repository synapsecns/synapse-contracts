// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {KappaMapUpgradeable} from "src-bridge/libraries/KappaMapUpgradeable.sol";

contract FasterMapTest is Test {
    using KappaMapUpgradeable for KappaMapUpgradeable.KappaMap;

    KappaMapUpgradeable.KappaMap internal map;

    uint256 internal constant AMOUNT = 5;

    function setUp() public {
        vm.warp(14000000);
    }

    // Add to Full (F) map, then remove all
    function testAdd1F(bytes32 key) public {
        vm.assume(key != bytes32(0));
        _add(key, 4 * AMOUNT);
        _poll(key, 4 * AMOUNT);
    }

    // Add to map, then remove until it's empty (E) two times
    function testAdd2E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 2; ++i) {
            bytes32 newKey = _add(key, 2 * AMOUNT);
            _poll(key, 2 * AMOUNT);
            key = newKey;
        }
    }

    // Add to map, then remove until it's empty (E) three times
    function testAdd3E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 3; ++i) {
            uint256 amount = i == 0 ? 2 * AMOUNT : AMOUNT;
            bytes32 newKey = _add(key, amount);
            _poll(key, amount);
            key = newKey;
        }
    }

    // Add to map, then remove until it's empty (E) four times
    function testAdd4E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 4; ++i) {
            bytes32 newKey = _add(key, AMOUNT);
            _poll(key, AMOUNT);
            key = newKey;
        }
    }

    function testUsage(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 4; ++i) {
            bytes32 newKey = _addCheck(key, AMOUNT);
            _pollCheck(key, AMOUNT);
            key = newKey;
        }
    }

    function _add(bytes32 key, uint256 amount) internal returns (bytes32) {
        for (uint256 i = 0; i < amount; i++) {
            bytes memory value = abi.encode(key);
            assertTrue(map.add(key, value));
            key = keccak256(value);
        }
        return key;
    }

    function _addCheck(bytes32 key, uint256 amount) internal returns (bytes32) {
        for (uint256 i = 0; i < amount; i++) {
			assertTrue(!map.contains(key), "Key already present");
            bytes memory value = abi.encode(key);
            assertTrue(map.add(key, value), "Key not added");
            assertTrue(map.contains(key), "New key not found");

            (bytes memory _value, ) = map.get(key);
            key = keccak256(value);
            assertTrue(key == keccak256(_value), "Value doesn't match");
        }
        return key;
    }

    function _poll(bytes32 key, uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            map.remove(key);
            key = keccak256(abi.encode(key));
        }
    }

    function _pollCheck(bytes32 key, uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            (bytes memory value, ) = map.remove(key);
            bytes32 newKey = keccak256(abi.encode(key));

            assertTrue(!map.contains(key), "Key not deleted");
            assertTrue(newKey == keccak256(value), "Wrong value");

            (value, ) = map.get(key);
            assertTrue(value.length == 0, "Data remains after deletion");
            key = newKey;
        }
    }
}
