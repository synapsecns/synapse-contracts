// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestEth is DefaultBridgeForkTest {
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0x2796317b0fF8538F253012862c06787Adfb8cEb6,
            wgas: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            tokenMint: 0x0f2D719407FdBeFF09D87557AbB7232601FD9F29, // SYN
            tokenWithdraw: 0x853d955aCEf822Db058eb8505911ED77F175b99e // FRAX
        });

    // kappas present at block 14650000
    bytes32[4] private kappas = [
        bytes32(0x58b29a4cf220b60a7e46b76b9831686c0bfbdbfea19721ef8f2192ba28514485),
        bytes32(0x3745754e018ed57dce0feda8b027f04b7e1369e7f74f1a247f5f7352d519021c),
        bytes32(0xea5bc18a60d2f1b9ba5e5f8bfef3cd112c3b1a1ef74a0de8e5989441b1722524),
        bytes32(0x1d4f3f6ed7690f1e5c1ff733d2040daa12fa484b3acbf37122ff334b46cf8b6d)
    ];

    bool internal constant IS_MAINNET = true;
    bool internal constant IS_GAS_WITHDRAWABLE = true;

    address internal constant NUSD = 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F;
    address internal constant NUSD_POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {} // solhint-disable-line no-empty-blocks

    function _initSwapArrays() internal override {
        _addTokenPool(NUSD, NUSD_POOL);
    }
}
