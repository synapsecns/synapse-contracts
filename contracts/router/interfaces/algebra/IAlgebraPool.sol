// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IAlgebraPool {
    function globalState()
        external
        view
        returns (
            uint160,
            int24,
            uint16 fee,
            uint16,
            uint8,
            uint8,
            bool
        );

    function token0() external view returns (address);

    function token1() external view returns (address);
}
