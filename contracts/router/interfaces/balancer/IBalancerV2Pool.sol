// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBalancerV2Pool {
    function getPoolId() external view returns (bytes32);
}
