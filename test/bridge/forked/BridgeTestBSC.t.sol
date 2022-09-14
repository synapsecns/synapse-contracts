// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestBSC is DefaultBridgeForkTest {
    // solhint-disable no-empty-blocks
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0xd123f70AE324d34A9E76b67a27bf77593bA8749f,
            wgas: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            tokenMint: 0xa4080f1778e69467E905B8d6F72f6e441f9e9484, //SYN
            tokenWithdraw: ZERO
        });

    // kappas present at block 19000000
    bytes32[4] private kappas = [
        bytes32(0x396d1038b343b069ec77c7f0ca678b227cdf1651fe351d440519417409ce0351),
        bytes32(0x7179c323f997907a91abe798af325ad87211c46fa618b0e88373a1c9753f1f7f),
        bytes32(0x2e29367f37c206dab43c683ca4148bbbd3b1c7825f225256708d85614ae1ea03),
        bytes32(0xe4801baa6784585b148736fa6a7b1cff2a8d8e4552cb6eaf4d34ee622df045a3)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_WITHDRAWABLE = false;

    address internal constant NUSD = 0x23b891e5C62E0955ae2bD185990103928Ab817b3;
    address internal constant NUSD_POOL = 0x28ec0B36F0819ecB5005cAB836F4ED5a2eCa4D13;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_WITHDRAWABLE, setup, kappas) {}

    function _initSwapArrays() internal override {
        _addTokenPool(NUSD, NUSD_POOL);
    }
}
