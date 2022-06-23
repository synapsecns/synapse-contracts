// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestArb is DefaultBridgeForkTest {
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9,
            nethPool: 0xa067668661C84476aFcDc6fA5D758C4c01C34352,
            nusdPool: 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40,
            neth: 0x3ea9B0ab55F34Fb188824Ee288CeaEfC63cf908e,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            wgas: ZERO,
            nusd: 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688,
            syn: 0x080F6AEd32Fc474DD5717105Dba5ea57268F46eb,
            originToken: 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a // GMX
        });

    // kappas present at block 10600000
    bytes32[4] private kappas = [
        bytes32(0x42308a78f0e1563ffb36719b5d60d4751b9975875490f7acb0eaf1a96d2d2cd6),
        bytes32(0x4a8d42610031767bd7fd42c2521848fb563b51202f7576e8ee881fcabacf27a7),
        bytes32(0x7ef45d179685768dd2a2a4a660305f4ac63a6d032dc9abfdc7acd45043881d41),
        bytes32(0x27454ce7fa3b7a20aa6e5fcd66703ea4ebd8971bbab3e72dd1dcb6a0802b5ade)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_ETH = true;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_ETH, setup, kappas) {} // solhint-disable-line no-empty-blocks
}
