// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultL2BridgeZapTest.sol";

contract L2BridgeZapTestArb is DefaultL2BridgeZapTest {
    // solhint-disable no-empty-blocks
    L2ZapTestSetup internal setup =
        L2ZapTestSetup({
            wethAddress: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            synapseBridge: 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9,
            tokenDeposit: 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a, // GMX
            tokenRedeem: 0x080F6AEd32Fc474DD5717105Dba5ea57268F46eb // SYN
        });

    address internal constant NETH = 0x3ea9B0ab55F34Fb188824Ee288CeaEfC63cf908e;
    address internal constant NETH_POOL = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;

    address internal constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;
    address internal constant NUSD_POOL = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;

    constructor() DefaultL2BridgeZapTest(setup) {}

    function _initSwapArrays() internal virtual override {
        _addBridgePool(NETH, NETH_POOL);
        _addBridgePool(NUSD, NUSD_POOL);
    }
}
