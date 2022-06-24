// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultL2BridgeZapTest.sol";

contract L2BridgeZapTestAvax is DefaultL2BridgeZapTest {
    // solhint-disable no-empty-blocks
    L2ZapTestSetup internal setup =
        L2ZapTestSetup({
            wethAddress: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7,
            synapseBridge: 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE,
            tokenDeposit: ZERO,
            tokenRedeem: 0x1f1E7c893855525b303f99bDF5c3c05Be09ca251 // SYN
        });

    address internal constant NETH = 0x19E1ae0eE35c0404f835521146206595d37981ae;
    address internal constant NETH_POOL = 0xdd60483Ace9B215a7c019A44Be2F22Aa9982652E;

    address internal constant NUSD = 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46;
    address internal constant NUSD_POOL = 0xED2a7edd7413021d440b09D654f3b87712abAB66;

    constructor() DefaultL2BridgeZapTest(setup) {}

    function _initSwapArrays() internal virtual override {
        _addBridgePool(NETH, NETH_POOL);
        _addBridgePool(NUSD, NUSD_POOL);
    }
}
