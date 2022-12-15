// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract MockSwap {
    function calculateSwap(
        uint8,
        uint8,
        uint256
    ) external pure returns (uint256) {
        return 0;
    }

    function swap(
        uint8,
        uint8,
        uint256,
        uint256,
        uint256
    ) external payable returns (uint256) {
        // Using payable saves a bit of gas here
        // We always revert, so this will not lead to locked ether
        revert("");
    }
}
