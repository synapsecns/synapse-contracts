// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestAurora is DefaultBridgeForkTest {
    // solhint-disable no-empty-blocks
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0xaeD5b25BE1c3163c907a471082640450F928DDFE,
            wgas: 0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB, // TriSolaris WETH
            tokenMint: 0xd80d8688b02B3FD3afb81cDb124F188BB5aD0445, //SYN
            tokenWithdraw: ZERO
        });

    // kappas present at block 68400000
    bytes32[4] private kappas = [
        bytes32(0xb7c657d30c7e8ffb23ab9242c500e13f6c0708f72fa4661d59d531ba57b1c1fe),
        bytes32(0x9a42d0bef608ba07f43547b97afcdba513416e8f911ebb0e38e344f0d50d67a6),
        bytes32(0x2b89321c8fc73102f79ebeb35569073e23852fe6bc8aee7c4aba775fb0095256),
        bytes32(0x1ffb874d7d099837439f58c943946861682fc1f948388bd18b1893c46a0272bb)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_WITHDRAWABLE = false;

    address internal constant NUSD = 0x07379565cD8B0CaE7c60Dc78e7f601b34AF2A21c;
    address internal constant NUSD_POOL = 0xcEf6C2e20898C2604886b888552CA6CcF66933B0;
    address internal constant NUSD_POOL_NEW = 0xCCd87854f58773fe75CdDa542457aC48E46c2D65;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {}

    function _initSwapArrays() internal override {
        _addTokenPool(NUSD, NUSD_POOL);
    }
}
