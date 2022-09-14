// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestKlay is DefaultBridgeForkTest {
    // solhint-disable no-empty-blocks
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0xAf41a65F786339e7911F4acDAD6BD49426F2Dc6b,
            wgas: 0x5819b6af194A78511c79C85Ea68D2377a7e9335f, // WKLAY
            tokenMint: ZERO, // SYN
            tokenWithdraw: ZERO
        });

    // kappas present at block 101222300
    bytes32[4] private kappas = [
        bytes32(0xd92055af2ea7cdf48fcfe57087beab9b103abdf3a450c2d507d7581bd232be4e),
        bytes32(0xd92055af2ea7cdf48fcfe57087beab9b103abdf3a450c2d507d7581bd232be4e),
        bytes32(0xd92055af2ea7cdf48fcfe57087beab9b103abdf3a450c2d507d7581bd232be4e),
        bytes32(0xd92055af2ea7cdf48fcfe57087beab9b103abdf3a450c2d507d7581bd232be4e)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_WITHDRAWABLE = true;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {}

    function _initSwapArrays() internal override {}
}
