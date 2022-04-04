// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRateLimiter {
    function addToRetryQueue(bytes32 kappa, bytes memory rateLimited) external;
    function checkAndUpdateAllowance(address token, uint256 amount) external returns (bool);
}