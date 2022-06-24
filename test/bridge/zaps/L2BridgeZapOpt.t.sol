// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultL2BridgeZapTest.sol";

contract L2BridgeZapTestOpt is DefaultL2BridgeZapTest {
    // solhint-disable no-empty-blocks
    L2ZapTestSetup internal setup =
        L2ZapTestSetup({
            wethAddress: 0x121ab82b49B2BC4c7901CA46B8277962b4350204,
            synapseBridge: 0xAf41a65F786339e7911F4acDAD6BD49426F2Dc6b,
            tokenDeposit: ZERO,
            tokenRedeem: 0x5A5fFf6F753d7C11A56A52FE47a177a87e431655 // SYN
        });

    address internal constant NETH = 0x809DC529f07651bD43A172e8dB6f4a7a0d771036;
    address internal constant NETH_POOL = 0xE27BFf97CE92C3e1Ff7AA9f86781FDd6D48F5eE9;

    address internal constant NUSD = 0x67C10C397dD0Ba417329543c1a40eb48AAa7cd00;
    address internal constant NUSD_POOL = 0xF44938b0125A6662f9536281aD2CD6c499F22004;

    constructor() DefaultL2BridgeZapTest(setup) {}

    function _initSwapArrays() internal virtual override {
        _addBridgePool(NETH, NETH_POOL);
        _addBridgePool(NUSD, NUSD_POOL);
    }
}
