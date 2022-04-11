// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Strings.sol";

// @dev StringsMock wraps strings for testing
contract StringsMock {
    function append(string memory a, string memory b)
    public
    pure
    returns (string memory)
    {
        return Strings.append(a,b);
    }

    function append(string memory a, string memory b, string memory c)
    public
    pure
    returns (string memory)
    {
        return Strings.append(a, b, c);
    }

    function append(string memory a, string memory b, string memory c, string memory d)
    public
    pure
    returns (string memory)
    {
        return Strings.append(a, b, c, d);
    }


    function toHex(bytes32 _bytes32) public pure returns (string memory) {
        return Strings.toHex(_bytes32);
    }


}