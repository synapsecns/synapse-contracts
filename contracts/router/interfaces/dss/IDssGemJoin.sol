// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IDssGemJoin {
    function gem() external view returns (address);

    function dec() external view returns (uint256);
}
