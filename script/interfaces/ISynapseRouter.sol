// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ISynapseRouter {
    function setSwapQuoter(address swapQuoter_) external;

    function swapQuoter() external view returns (address);
}
