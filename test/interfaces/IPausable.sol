// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IPausable {
    function paused() external view returns (bool);

    function pause() external;

    function unpause() external;
}
