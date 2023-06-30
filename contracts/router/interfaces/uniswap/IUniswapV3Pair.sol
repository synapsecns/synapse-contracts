// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IUniswapV3Pair {
    function fee() external view returns (uint24);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
