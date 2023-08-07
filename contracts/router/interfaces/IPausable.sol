// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPausable {
    function paused() external view returns (bool);
}
