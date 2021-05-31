// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

library AddressArrayUtils {
    function contains(address[] memory self, address _address)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < self.length; i++) {
            if (_address == self[i]) {
                return true;
            }
        }
        return false;
    }
}