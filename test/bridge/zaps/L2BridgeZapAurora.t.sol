// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./DefaultL2BridgeZapTest.sol";

// solhint-disable func-name-mixedcase

contract L2BridgeZapTestAurora is DefaultL2BridgeZapTest {
    // solhint-disable no-empty-blocks
    L2ZapTestSetup internal setup =
        L2ZapTestSetup({
            wethAddress: 0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB, // TriSolaris WETH
            synapseBridge: 0xaeD5b25BE1c3163c907a471082640450F928DDFE,
            tokenDeposit: ZERO,
            tokenRedeem: 0xd80d8688b02B3FD3afb81cDb124F188BB5aD0445 // SYN
        });

    address internal constant NUSD = 0x07379565cD8B0CaE7c60Dc78e7f601b34AF2A21c;
    address internal constant NUSD_POOL = 0xcEf6C2e20898C2604886b888552CA6CcF66933B0;
    address internal constant NUSD_POOL_NEW = 0xCCd87854f58773fe75CdDa542457aC48E46c2D65;

    constructor() DefaultL2BridgeZapTest(setup) {}

    function _initSwapArrays() internal virtual override {
        _addBridgePool(NUSD, NUSD_POOL);
    }

    function test_updatePool() public {
        _clearSavedPools();
        _addBridgePool(NUSD, NUSD_POOL_NEW);

        (uint8 bridgeTokenIndex, uint8 swapTokens) = _getBridgeTokenIndex(0);
        IERC20 bridgeToken = IERC20(NUSD);
        for (uint8 indexFrom = 0; indexFrom < swapTokens; ++indexFrom) {
            // check all candidates for "initial token"
            if (indexFrom == bridgeTokenIndex) continue;
            IERC20 tokenFrom = _getToken(0, indexFrom);
            // Use 1.0 worth of tokens for swapping
            uint256 amount = 10**ERC20(address(tokenFrom)).decimals();
            // TODO: estimate the metapool swap quote
            uint256 quote = 0;
            // deal test tokens to user and approve Zap to spend them
            _prepareTestTokens(tokenFrom, amount);
            _logSwapTest(0, indexFrom, bridgeTokenIndex);
            // need exact quote to be able to check data
            vm.expectEmit(true, false, false, false);
            _runTest_swapAndRedeemAndSwap(bridgeToken, indexFrom, bridgeTokenIndex, amount, quote);
        }
    }
}
