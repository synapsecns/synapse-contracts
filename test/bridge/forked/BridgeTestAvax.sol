// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultBridgeForkTest.sol";

contract BridgeTestAvax is DefaultBridgeForkTest {
    BridgeTestSetup private setup =
        BridgeTestSetup({
            bridge: 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE,
            nethPool: 0xdd60483Ace9B215a7c019A44Be2F22Aa9982652E, // AaveWrapper
            nusdPool: 0xED2a7edd7413021d440b09D654f3b87712abAB66,
            neth: 0x19E1ae0eE35c0404f835521146206595d37981ae,
            weth: 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB,
            wgas: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7, // WAVAX
            nusd: 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46,
            syn: 0x1f1E7c893855525b303f99bDF5c3c05Be09ca251,
            originToken: ZERO
        });

    // kappas present at block 13897000
    bytes32[4] private kappas = [
        bytes32(0x156feccddaf55f130f9685cc7660769919a777b548c580e4f62977ae7a6b5dc3),
        bytes32(0xd6f1ba89bb5210df0d1fef6822774be36010a82b85a7fc2b2be7fa7845967d0e),
        bytes32(0x27174336b55a799bfa24804089354e0c962d89944ca3533da5512a5b6544d49f),
        bytes32(0x2fb5a5a3a37a82d063e3e87a5c4a0857298d0ed60650095b74e981b728003e6b)
    ];

    bool internal constant IS_MAINNET = false;
    bool internal constant IS_GAS_ETH = false;

    constructor() DefaultBridgeForkTest(IS_MAINNET, IS_GAS_ETH, setup, kappas) {} // solhint-disable-line no-empty-blocks
}
