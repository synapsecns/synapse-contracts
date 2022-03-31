// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract AvaxJewelSwap {
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        return 0;
    }

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256) {
        revert("There is no swap");
    }
}
