// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";

import {Action, ActionLib, LimitedToken} from "../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";

import {BasicSwapQuoterV2Test} from "./BasicSwapQuoterV2.t.sol";

// solhint-disable max-states-count
contract SwapQuoterV2FindConnectedTokensTest is BasicSwapQuoterV2Test {
    function testFindConnectedTokensDefaultPoolActionSwap() public {
        addL2Pools();
        // Bridge Default Pool for nETH is nETH/WETH
        address tokenOut = weth;
        // Only first entry is connected: Swap nETH -> WETH
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: Action.Swap.mask(), token: neth}),
            LimitedToken({actionMask: maskExceptAction(Action.Swap), token: neth}),
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            LimitedToken({actionMask: ActionLib.allActions(), token: usdc})
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(0));
    }

    function testFindConnectedTokensDefaultPoolActionSwapToETH() public {
        addL2Pools();
        // Bridge Default Pool for nETH is nETH/WETH
        address tokenOut = UniversalTokenLib.ETH_ADDRESS;
        // Only first entry is connected: Swap nETH -> WETH -> ETH
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: Action.Swap.mask(), token: neth}), // index = 0
            LimitedToken({actionMask: maskExceptAction(Action.Swap), token: neth}),
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            LimitedToken({actionMask: ActionLib.allActions(), token: usdc})
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(0));
    }

    function testFindConnectedTokensLinkedPoolActionSwap() public {
        addL2Pools();
        // Bridge Linked Pool for nUSD is nUSD/USDC.e/USDT
        address tokenOut = usdcE;
        // Only second entry is connected: Swap nUSD -> USDC.e
        // USDT -> USDC.e also possible, but pool is not whitelisted for USDT
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: maskExceptAction(Action.Swap), token: nusd}),
            LimitedToken({actionMask: Action.Swap.mask(), token: nusd}), // index = 1
            LimitedToken({actionMask: ActionLib.allActions(), token: usdt}),
            LimitedToken({actionMask: ActionLib.allActions(), token: neth})
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(1));
    }

    function testFindConnectedTokensLinkedPoolActionSwapToETH() public {
        addL2Pools();
        address linkedPoolNeth = deployLinkedPool(neth, poolNethWeth);
        // Replace nETH Default Pool with Linked Pool
        SwapQuoterV2.BridgePool[] memory newPools = toArray(
            SwapQuoterV2.BridgePool({bridgeToken: neth, poolType: SwapQuoterV2.PoolType.Linked, pool: linkedPoolNeth})
        );
        vm.prank(owner);
        quoter.addPools(newPools);
        address tokenOut = UniversalTokenLib.ETH_ADDRESS;
        // Only third entry is connected: Swap nETH -> WETH -> ETH
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: maskExceptAction(Action.Swap), token: neth}),
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            LimitedToken({actionMask: Action.Swap.mask(), token: neth}), // index = 2
            LimitedToken({actionMask: ActionLib.allActions(), token: usdc})
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(2));
    }

    function testFindConnectedTokensDefaultPoolActionRemoveLiquidity() public {
        addL1Pool();
        // Bridge Default Pool for nexusNusd is nexusDai/nexusUsdc/nexusUsdt
        address tokenOut = nexusUsdc;
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: maskExceptAction(Action.RemoveLiquidity), token: nexusNusd}),
            LimitedToken({actionMask: Action.RemoveLiquidity.mask(), token: nexusNusd}) // index = 1
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(1));
    }

    function testFindConnectedTokensActionHandleETH() public {
        addL2Pools();
        address tokenOut = UniversalTokenLib.ETH_ADDRESS;
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: Action.HandleEth.mask(), token: neth}),
            LimitedToken({actionMask: Action.HandleEth.mask(), token: nusd}),
            LimitedToken({actionMask: maskExceptAction(Action.HandleEth), token: weth}),
            LimitedToken({actionMask: Action.HandleEth.mask(), token: weth}) // index = 3
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(3));
    }

    function testFindConnectedTokensSameToken() public {
        address tokenOut = neth;
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            LimitedToken({actionMask: 0, token: neth}) // index = 1
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(1));
    }

    function testFindConnectedTokensNoneConnected() public {
        addL2Pools();
        // USDC is only connected to USDC in this scenario
        // USDC.e -> USDC is possible, but not
        address tokenOut = usdc;
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            LimitedToken({actionMask: ActionLib.allActions(), token: neth}),
            LimitedToken({actionMask: ActionLib.allActions(), token: weth}),
            LimitedToken({actionMask: ActionLib.allActions(), token: usdt}),
            LimitedToken({actionMask: ActionLib.allActions(), token: usdcE})
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, new uint256[](0));
    }

    function testFindConnectedTokensMultipleConnected() public {
        addL1Pool();
        // Bridge Default Pool for nexusNusd is nexusDai/nexusUsdc/nexusUsdt
        address tokenOut = nexusUsdc;
        LimitedToken[] memory tokensIn = toArray(
            LimitedToken({actionMask: 0, token: nexusUsdc}),
            LimitedToken({actionMask: Action.RemoveLiquidity.mask(), token: nexusNusd})
        );
        (uint256 amountFound, bool[] memory isConnected) = quoter.findConnectedTokens(tokensIn, tokenOut);
        checkConnectedTokens(amountFound, isConnected, toArray(0, 1));
    }

    function checkConnectedTokens(
        uint256 amountFound,
        bool[] memory isConnected,
        uint256[] memory expectedIndexes
    ) internal {
        assertEq(amountFound, expectedIndexes.length);
        for (uint256 i = 0; i < isConnected.length; i++) {
            bool expectedConnected = false;
            for (uint256 j = 0; j < expectedIndexes.length; j++) {
                if (i == expectedIndexes[j]) {
                    expectedConnected = true;
                    break;
                }
            }
            assertEq(isConnected[i], expectedConnected);
        }
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function maskExceptAction(Action action) internal pure returns (uint256) {
        return ActionLib.allActions() ^ action.mask();
    }
}
