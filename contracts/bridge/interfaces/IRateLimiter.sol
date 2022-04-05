// SPDX-License-Identifier: MIT

pragma solidity >=0.4.23 <0.9.0;

interface IRateLimiter {
    function addToRetryQueue(bytes32 kappa, bytes memory rateLimited) external;
    function checkAndUpdateAllowance(address token, uint256 amount) external returns (bool);
}