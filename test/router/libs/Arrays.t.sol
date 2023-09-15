// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Strings} from "@openzeppelin/contracts-4.5.0/utils/Strings.sol";

import {ArraysLibHarness} from "../harnesses/ArraysLibHarness.sol";
import {BridgeToken} from "../../../contracts/router/libs/Structs.sol";
import {Arrays} from "../../../contracts/router/libs/Arrays.sol";

import {Test} from "forge-std/Test.sol";

contract ArraysLibraryTest is Test {
    ArraysLibHarness public libHarness;
    uint256 public constant rows = 3;

    function setUp() public {
        libHarness = new ArraysLibHarness();
    }

    function getNestedBridgeTokensArray() public view returns (BridgeToken[][] memory unflattened, uint256 count) {
        // assemble list of lists
        unflattened = new BridgeToken[][](rows);
        for (uint256 i = 0; i < rows; i++) {
            uint256 cols = i + 1;
            unflattened[i] = new BridgeToken[](cols);
            for (uint256 j = 0; j < cols; j++) {
                unflattened[i][j] = BridgeToken({symbol: Strings.toString(count), token: address(uint160(count))});
                count++;
            }
        }
    }

    function getNestedAddressesArray() public view returns (address[][] memory unflattened, uint256 count) {
        // assemble list of lists
        unflattened = new address[][](rows);
        for (uint256 i = 0; i < rows; i++) {
            uint256 cols = i + 1;
            unflattened[i] = new address[](cols);
            for (uint256 j = 0; j < cols; j++) {
                unflattened[i][j] = address(uint160(count));
                count++;
            }
        }
    }

    function getBridgeTokensArray() public view returns (BridgeToken[] memory bridgeTokens, uint256 num) {
        uint256 count;
        for (uint256 i = 0; i < rows; i++) count += (i + 1); // 1 + 2 + ... + rows

        bridgeTokens = new BridgeToken[](count);
        for (uint256 i = 0; i < count; i++) {
            bridgeTokens[i] = BridgeToken({
                symbol: Strings.toString(i / 2),
                token: address(uint160(i / 2)) // divide by 2 for non-unique els: [0, 0, 1, 1, ...]
            });
            if (i % 2 == 0) num++;
        }
    }

    function getAddressesArray() public view returns (address[] memory addrs, uint256 num) {
        uint256 count;
        for (uint256 i = 0; i < rows; i++) count += (i + 1); // 1 + 2 + ... + rows

        addrs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addrs[i] = address(uint160(i / 2)); // divide by 2 for non-unique els: [0, 0, 1, 1, ...]
            if (i % 2 == 0) num++;
        }
    }

    function testFlatten_BridgeToken() public {
        (BridgeToken[][] memory unflattened, uint256 count) = getNestedBridgeTokensArray();

        BridgeToken[] memory expect = new BridgeToken[](count);
        for (uint256 i = 0; i < count; i++)
            expect[i] = BridgeToken({symbol: Strings.toString(i), token: address(uint160(i))});

        BridgeToken[] memory actual = libHarness.flatten(unflattened, count);
        checkBridgeTokens(actual, expect);
    }

    function testFlatten_BridgeToken_revert_ArrayLengthInvalid() public {
        (BridgeToken[][] memory unflattened, uint256 count) = getNestedBridgeTokensArray();
        vm.expectRevert(abi.encodeWithSelector(Arrays.ArrayLengthInvalid.selector, count));
        libHarness.flatten(unflattened, count + 1);
    }

    function testFlatten_Address() public {
        (address[][] memory unflattened, uint256 count) = getNestedAddressesArray();

        address[] memory expect = new address[](count);
        for (uint256 i = 0; i < count; i++) expect[i] = address(uint160(i));

        address[] memory actual = libHarness.flatten(unflattened, count);
        checkAddresses(actual, expect);
    }

    function testFlatten_Address_revert_ArrayLengthInvalid() public {
        (address[][] memory unflattened, uint256 count) = getNestedAddressesArray();
        vm.expectRevert(abi.encodeWithSelector(Arrays.ArrayLengthInvalid.selector, count));
        libHarness.flatten(unflattened, count + 1);
    }

    function testTokens_BridgeToken() public {
        (BridgeToken[] memory b, ) = getBridgeTokensArray();

        address[] memory expect = new address[](b.length);
        for (uint256 i = 0; i < b.length; i++) expect[i] = address(uint160(i / 2));

        address[] memory actual = libHarness.tokens(b);
        checkAddresses(actual, expect);
    }

    function testUnique_Address() public {
        (address[] memory unfiltered, uint256 num) = getAddressesArray();

        address[] memory expect = new address[](num - 1); // zero address excluded
        for (uint256 i = 1; i < num; i++) expect[i - 1] = address(uint160(i));

        address[] memory actual = libHarness.unique(unfiltered);
        checkAddresses(actual, expect);
        assertEq(actual.length, expect.length);
    }

    function testContains_Address() public {
        (address[] memory l, uint256 num) = getAddressesArray();

        // should contain addr(1) but not addr(7)
        assertTrue(libHarness.contains(l, address(uint160(1))));
        assertFalse(libHarness.contains(l, address(uint160(2 * num + 1))));
    }

    function testAppend_Address() public {
        (address[] memory l, uint256 num) = getAddressesArray();

        address[] memory expect = new address[](l.length + 1);
        for (uint256 i = 0; i < l.length; i++) expect[i] = l[i];
        expect[l.length] = address(uint160(2 * num + 1));

        // append addr(7)
        address[] memory actual = libHarness.append(l, address(uint160(2 * num + 1)));
        checkAddresses(actual, expect);
    }

    function checkAddresses(address[] memory actual, address[] memory expect) public {
        for (uint256 i = 0; i < actual.length; i++) {
            assertEq(actual[i], expect[i]);
        }
    }

    function checkBridgeTokens(BridgeToken[] memory actual, BridgeToken[] memory expect) public {
        for (uint256 i = 0; i < actual.length; i++) {
            assertEq(actual[i].symbol, expect[i].symbol);
            assertEq(actual[i].token, expect[i].token);
        }
    }
}
