// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestOpt is DefaultBridgeForkTest {
    // solhint-disable no-empty-blocks
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0xAf41a65F786339e7911F4acDAD6BD49426F2Dc6b,
            wgas: 0x121ab82b49B2BC4c7901CA46B8277962b4350204,
            tokenMint: 0x5A5fFf6F753d7C11A56A52FE47a177a87e431655, //SYN
            tokenWithdraw: ZERO
        });

    // kappas present at block 6600000
    bytes32[4] private kappas = [
        bytes32(0xb11f09f1777a373fe5fe7ef1933beb3a2fd559a2d1cbc2b54c48a2b7b34daf57),
        bytes32(0x11c2af579532fefb99d86c93a2bb46862273143a53651df46b0a50311e2bcc84),
        bytes32(0xa023767a95deef3bcd0d591fdffad4a4d97f663eca3c756fb0caef74288768e0),
        bytes32(0x9446e4244819cd7c154cbebc7bdcd9f18b58897499878f5da534777e65f78b2f)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_WITHDRAWABLE = false;

    address internal constant NUSD = 0x67C10C397dD0Ba417329543c1a40eb48AAa7cd00;
    address internal constant NUSD_POOL = 0xF44938b0125A6662f9536281aD2CD6c499F22004;

    address internal constant NETH = 0x809DC529f07651bD43A172e8dB6f4a7a0d771036;
    address internal constant NETH_POOL = 0xE27BFf97CE92C3e1Ff7AA9f86781FDd6D48F5eE9;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {}

    function _initSwapArrays() internal override {
        _addTokenPool(NUSD, NUSD_POOL);
        _addTokenPool(NETH, NETH_POOL);
    }
}
