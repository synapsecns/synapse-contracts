// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {Action, ActionLib, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";

import {BasicSwapQuoterV2Test, SwapQuoterV2} from "./BasicSwapQuoterV2.t.sol";

contract SwapQuoterV2GetAmountOutMintedTest is BasicSwapQuoterV2Test {
    // In destination requests actionMask is set to
    // - For minted tokens: Action.Swap

    uint256 public maskMintedToken = Action.Swap.mask();

    /// Three potential outcomes are available:
    /// 1. `tokenIn` and `tokenOut` represent the same token address (identical tokens).
    /// 2. `tokenIn` and `tokenOut` represent different addresses. No trade path from `tokenIn` to `tokenOut` is found.
    /// 3. `tokenIn` and `tokenOut` represent different addresses. Trade path from `tokenIn` to `tokenOut` is found.

    // ═════════════════════════════════ GENERIC DESTINATION CHECKS: MINTED TOKENS ═════════════════════════════════════

    function checkMintedSameToken(address tokenIn) public {
        uint256 amount = 10**18;
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: maskMintedToken, token: tokenIn});
        address tokenOut = tokenIn;
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amount);
        assertTrue(quoter.areConnectedTokens(tokenIn_, tokenOut));
        assertSameTokenSwapQuery(query, tokenOut, amount);
    }

    function checkMintedNoTradePathExists(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public {
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: maskMintedToken, token: tokenIn});
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amountIn);
        assertFalse(quoter.areConnectedTokens(tokenIn_, tokenOut));
        assertNoPathSwapQuery(query, tokenOut);
    }

    function checkMintedTradePathFound(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        bytes memory expectedParams
    ) public {
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: maskMintedToken, token: tokenIn});
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amountIn);
        assertTrue(quoter.areConnectedTokens(tokenIn_, tokenOut));
        assertPathFoundSwapQuery(query, tokenOut, expectedAmountOut, expectedParams);
    }

    // ══════════════════════════════════════════════ (1) SAME TOKENS ══════════════════════════════════════════════════

    function testGetAmountOutMintedSameBridgeToken() public {
        addL2Pools();
        // nETH -> nETH
        checkMintedSameToken(neth);
    }

    // ═════════════════════════════════════════════ (2) NO SWAP FOUND ═════════════════════════════════════════════════

    function testGetAmountOutMintedNoTradePath() public {
        addL2Pools();
        // nUSD -> USDC is not supported (USDC.e is the correct destination token)
        checkMintedNoTradePathExists(nusd, usdc, 10**18);
    }

    function testGetAmountOutMintedNoTradePathToETH() public {
        addL2Pools();
        // nUSD -> ETH is not supported
        checkMintedNoTradePathExists(nusd, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    function testGetAmountOutMintedNoWhitelistedPool() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH -> WETH is possible, but not whitelisted
        checkMintedNoTradePathExists(neth, weth, 10**18);
    }

    function testGetAmountOutMintedNoWhitelistedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH -> WETH -> ETH is possible, but not whitelisted
        checkMintedNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ══════════════════════════════ (3A) SWAP FOUND USING ORIGIN-ONLY DEFAULT POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as the origin-only pools could not be used on destination requests.

    function testGetAmountOutMintedSwapFoundOriginOnlyDefaultPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nUSD -> USDT is possible, but only via origin-only pool
        checkMintedNoTradePathExists(nusd, usdt, 10**18);
    }

    function testGetAmountOutMintedSwapFoundOriginOnlyDefaultPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH -> ETH is possible, but only via origin-only pool
        checkMintedNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ═══════════════════════════════ (3B) SWAP FOUND USING ORIGIN-ONLY LINKED POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as the origin-only pools could not be used on destination requests.

    function testGetAmountOutMintedSwapFoundOriginOnlyLinkedPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // nUSD -> USDT is possible, but only via origin-only pool
        checkMintedNoTradePathExists(nusd, usdt, 10**18);
    }

    function testGetAmountOutMintedSwapFoundOriginOnlyLinkedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH -> ETH is possible, but only via origin-only pool
        checkMintedNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ═════════════════════════════════ (3C) SWAP FOUND USING BRIDGE DEFAULT POOL ═════════════════════════════════════

    // These tests result in valid SwapQuery, as the bridge pools are used on destination requests.

    function testGetAmountOutMintedSwapFoundBridgeDefaultPool() public {
        addL2Pools();
        // nETH(0) -> WETH (1)
        uint256 amountIn = 10**18;
        checkMintedTradePathFound({
            tokenIn: neth,
            tokenOut: weth,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 0, 1)
        });
    }

    function testGetAmountOutMintedSwapFoundBridgeDefaultPoolToETH() public {
        addL2Pools();
        // nETH(0) -> ETH (1)
        uint256 amountIn = 10**18;
        checkMintedTradePathFound({
            tokenIn: neth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 0, 1)
        });
    }

    // ═════════════════════════════════ (3D) SWAP FOUND USING BRIDGE LINKED POOL ══════════════════════════════════════

    // These tests result in valid SwapQuery, as the bridge pools are used on destination requests.

    function testGetAmountOutMintedSwapFoundBridgeLinkedPool() public {
        addL2Pools();
        // nUSD(0) -> USDC.e (1)
        uint256 amountIn = 10**18;
        checkMintedTradePathFound({
            tokenIn: nusd,
            tokenOut: usdcE,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(linkedPoolNusd, 0, 1)
        });
    }

    function testGetAmountOutMintedSwapFoundBridgeLinkedPoolToETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // nETH(0) -> ETH (1)
        uint256 amountIn = 10**18;
        checkMintedTradePathFound({
            tokenIn: neth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(linkedPool, 0, 1)
        });
    }

    // ════════════════════════════════════════════ (3E) ADD LIQUIDITY ═════════════════════════════════════════════════

    // These tests result in empty SwapQuery, as add liquidity is not supported on destination requests.

    function testGetAmountOutMintedAddLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: USDC -> nUSD
        checkMintedNoTradePathExists(nexusUsdc, nexusNusd, 10**6);
    }

    function testGetAmountOutMintedAddLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Add nexus pool as Bridge Pool for nexusUSDC
        SwapQuoterV2.BridgePool[] memory newPools = toArray(
            SwapQuoterV2.BridgePool({
                bridgeToken: nexusUsdc,
                poolType: SwapQuoterV2.PoolType.Default,
                pool: nexusPoolDaiUsdcUsdt
            })
        );
        vm.prank(owner);
        quoter.addPools(newPools);
        // Nexus pool: USDC -> nUSD
        checkMintedNoTradePathExists(nexusUsdc, nexusNusd, 10**6);
    }

    // LinkedPools don't support Add Liquidity

    function testGetAmountOutMintedAddLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        // Linked Nexus pool is whitelisted for USDC in the next call
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: USDC -> nUSD
        checkMintedNoTradePathExists(nexusUsdc, nexusNusd, 10**6);
    }

    function testGetAmountOutMintedAddLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: USDC -> nUSD
        checkMintedNoTradePathExists(nexusUsdc, nexusNusd, 10**6);
    }

    // ═══════════════════════════════════════════ (3F) REMOVE LIQUIDITY ═══════════════════════════════════════════════

    // These tests result in empty SwapQuery, as remove liquidity is not supported for minted tokens.

    function testGetAmountOutMintedRemoveLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: nUSD -> USDT
        checkMintedNoTradePathExists(nexusNusd, nexusUsdt, 10**18);
    }

    function testGetAmountOutMintedRemoveLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: nUSD -> USDT
        checkMintedNoTradePathExists(nexusNusd, nexusUsdt, 10**18);
    }

    // LinkedPools don't support Remove Liquidity

    function testGetAmountOutMintedRemoveLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        checkMintedNoTradePathExists(nexusNusd, nexusUsdt, 10**18);
    }

    function testGetAmountOutMintedRemoveLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        checkMintedNoTradePathExists(nexusNusd, nexusUsdt, 10**18);
    }

    // ══════════════════════════════════════════════ (3G) HANDLE ETH ══════════════════════════════════════════════════

    // These tests result in empty SwapQuery, as handle eth is not supported for minted tokens.

    function testGetAmountOutMintedHandleEthFoundToETH() public {
        addL2Pools();
        // WETH -> ETH
        checkMintedNoTradePathExists(weth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }
}
