// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "../../contracts/bridge/utils/BridgeConfigV3Lens.sol";

// solhint-disable func-name-mixedcase
contract BridgeConfigV3LensTest is Test {
    BridgeConfigV3Lens internal lens;

    function setUp() public {
        lens = new BridgeConfigV3Lens();
    }

    function test_stringToAddress(address addr, bool toLower) public {
        string memory str = toString(addr, toLower);
        address newAddr = lens.stringToAddress(str);
        assertEq(newAddr, addr, "Roundtrip test failed");
    }

    function test_addressToString() public {
        address addr = 0x5217c83ca75559B1f8a8803824E5b7ac233A12a1;
        emit log_named_address("address", addr);
        emit log_named_string("toLower", toString(addr, true));
        emit log_named_string("toUpper", toString(addr, false));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║            ADDRESS -> STRING (CODE FROM BRIDGE CONFIG V3)            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function toString(address x, bool toLower) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi, toLower);
            s[2 * i + 1] = char(lo, toLower);
        }

        string memory addrPrefix = "0x";

        return concat(addrPrefix, string(s));
    }

    function concat(string memory _x, string memory _y) internal pure returns (string memory) {
        bytes memory _xBytes = bytes(_x);
        bytes memory _yBytes = bytes(_y);

        string memory _tmpValue = new string(_xBytes.length + _yBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint256 i;
        uint256 j;

        for (i = 0; i < _xBytes.length; i++) {
            _newValue[j++] = _xBytes[i];
        }

        for (i = 0; i < _yBytes.length; i++) {
            _newValue[j++] = _yBytes[i];
        }

        return string(_newValue);
    }

    function char(bytes1 b, bool toLower) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) {
            c = bytes1(uint8(b) + uint8(bytes1("0")));
        } else if (toLower) {
            c = bytes1(uint8(b) - 10 + uint8(bytes1("a")));
        } else {
            c = bytes1(uint8(b) - 10 + uint8(bytes1("A")));
        }
    }
}