// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestBoba is DefaultBridgeForkTest {
    // solhint-disable no-empty-blocks
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0x432036208d2717394d2614d6697c46DF3Ed69540,
            wgas: 0xd203De32170130082896b4111eDF825a4774c18E,
            tokenMint: 0xb554A55358fF0382Fb21F0a478C3546d1106Be8c, //SYN
            tokenWithdraw: ZERO
        });

    // kappas present at block 697000
    bytes32[4] private kappas = [
        bytes32(0x113bb38ded0a49446d12b54b9387e15648833dffa7ee44efe65432f803222950),
        bytes32(0x3998f0a20330cb7cab5ff95c4b54b1897b015e19db6e15f2c78ebbfbd62814ca),
        bytes32(0x3b0b1eb39940f8b909258865a24a93946f0c597d1e90a867caec01aeb9d6b9e3),
        bytes32(0xf153aef91cdd5d606b4d83fac85f523ac8a0cdbe439ed11330d973c3ec7af7f0)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_WITHDRAWABLE = false;

    address internal constant NUSD = 0x6B4712AE9797C199edd44F897cA09BC57628a1CF;
    address internal constant NUSD_POOL = 0x75FF037256b36F15919369AC58695550bE72fead;

    address internal constant NETH = 0x96419929d7949D6A801A6909c145C8EEf6A40431;
    address internal constant NETH_POOL = 0x753bb855c8fe814233d26Bb23aF61cb3d2022bE5;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {}

    function _initSwapArrays() internal override {
        _addTokenPool(NUSD, NUSD_POOL);
        _addTokenPool(NETH, NETH_POOL);
    }
}
