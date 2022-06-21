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

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_ETH = true;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_ETH, setup) {} // solhint-disable-line no-empty-blocks
}
