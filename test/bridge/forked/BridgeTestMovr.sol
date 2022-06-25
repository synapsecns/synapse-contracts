// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestMovr is DefaultBridgeForkTest {
    // solhint-disable no-empty-blocks
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0xaeD5b25BE1c3163c907a471082640450F928DDFE,
            wgas: 0x98878B06940aE243284CA214f92Bb71a2b032B8A,
            tokenMint: 0xd80d8688b02B3FD3afb81cDb124F188BB5aD0445, //SYN
            tokenWithdraw: 0x76906411D07815491A5E577022757aD941fb5066 // veSOLAR
        });

    // kappas present at block 1730000
    bytes32[4] private kappas = [
        bytes32(0xa754cc36b39979866c76e0de4fa7fd32b3b6e0b96abc06ea763e399ac11ad9a3),
        bytes32(0xae30f5d4b12aeb33e4adbe362d99e1d997f4849cda3dcf6fd3c87c7df7e2808a),
        bytes32(0xb0bb7c2abc99805f98b922d3e7457edf501d8e2295dc2dd2e853116f3880a562),
        bytes32(0x5c39b50f78d78a93ae30790b02b1ddf21284ab1437eea0ed11085ce4c13cbe46)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_WITHDRAWABLE = true;

    address internal constant BRIDGE_ADMIN = 0x4bA30618fDcb184eC01a9B3CAe258CFc5786E70E;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {}

    function _initSwapArrays() internal override {
        // TODO: set WETH_ADDRESS on Moonriver bridge
        _setWethAddress(BRIDGE_ADMIN);
    }
}
