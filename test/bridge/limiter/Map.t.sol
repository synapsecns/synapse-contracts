// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {EnumerableMapUpgradeable} from "contracts/bridge/libraries/EnumerableMapUpgradeable.sol";

contract MapTest is Test {
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.Bytes32ToStructMap;

    EnumerableMapUpgradeable.Bytes32ToStructMap internal map;

    uint256 internal constant AMOUNT = 5;

    function setUp() public {
        vm.warp(14000000);
    }

    // Add to Full (F) map, then remove all
    function testAdd1F(bytes32 key) public {
        vm.assume(key != bytes32(0));
        _add(key, 4 * AMOUNT);
        _poll(4 * AMOUNT);
    }

    // Add to map, then remove until it's empty (E) two times
    function testAdd2E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 2; ++i) {
            key = _add(key, 2 * AMOUNT);
            _poll(2 * AMOUNT);
        }
    }

    // Add to map, then remove until it's empty (E) three times
    function testAdd3E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 3; ++i) {
            uint256 amount = i == 0 ? 2 * AMOUNT : AMOUNT;
            key = _add(key, amount);
            _poll(amount);
        }
    }

    // Add to map, then remove until it's empty (E) four times
    function testAdd4E(bytes32 key) public {
        vm.assume(key != bytes32(0));
        for (uint256 i = 0; i < 4; ++i) {
            key = _add(key, AMOUNT);
            _poll(AMOUNT);
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
            assertTrue(map.set(key, value));
            key = keccak256(value);
        }
        return key;
    }

    function _addCheck(bytes32 key, uint256 amount) internal returns (bytes32) {
        for (uint256 i = 0; i < amount; i++) {
            assertTrue(!map.contains(key), "Key already present");
            bytes memory value = abi.encode(key);
            assertTrue(map.set(key, value), "Key not added");
            assertTrue(map.contains(key), "New key not found");

            (bytes memory _value, ) = map.get(key);
            key = keccak256(value);
            assertTrue(key == keccak256(_value), "Value doesn't match");
        }
        return key;
    }

    function _poll(uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            (bytes32 key, , ) = map.at(0);
            map.remove(key);
        }
    }

    function _pollCheck(uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            (bytes32 key, bytes memory value, ) = map.at(0);

            assertTrue(map.remove(key), "Key removal failed");
            assertTrue(!map.contains(key), "Key not deleted");
            assertTrue(
                keccak256(abi.encode(key)) == keccak256(value),
                "Wrong value"
            );
        }
    }
}
