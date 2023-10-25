// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IAlgebraPool {
    function token0() external view returns (address);

    function token1() external view returns (address);
}
