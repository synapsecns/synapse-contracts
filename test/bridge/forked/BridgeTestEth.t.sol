// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestEth is DefaultBridgeForkTest {
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0x2796317b0fF8538F253012862c06787Adfb8cEb6,
            nethPool: ZERO,
            nusdPool: 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8,
            neth: ZERO,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            wgas: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            nusd: 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F,
            syn: 0x0f2D719407FdBeFF09D87557AbB7232601FD9F29,
            originToken: 0x853d955aCEf822Db058eb8505911ED77F175b99e // FRAX
        });

    bool internal constant IS_MAINNET = true;
    bool internal constant IS_GAS_ETH = true;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_ETH, setup) {} // solhint-disable-line no-empty-blocks
}
