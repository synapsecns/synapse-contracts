// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IGasConfig {
    function setMaxGasPrice(uint256 chainID, uint256 maxPrice) external;
    function getMaxGasPrice(uint256 chainID) external view returns (uint256);
}