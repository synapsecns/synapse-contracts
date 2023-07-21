// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IDssPsm {
    function dai() external view returns (address);

    function gemJoin() external view returns (address);

    function buyGem(address usr, uint256 gemAmt) external;

    function sellGem(address usr, uint256 gemAmt) external;
}
