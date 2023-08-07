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

    // ══════════════════════════════════════════════ (1) SAME TOKENS ══════════════════════════════════════════════════

    function testGetAmountOutMintedSameBridgeToken() public {
        addL2Pools();
        // nETH -> nETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            neth,
            amount
        );
        assertSameTokenSwapQuery(query, neth, amount);
    }

    // ═════════════════════════════════════════════ (2) NO SWAP FOUND ═════════════════════════════════════════════════

    function testGetAmountOutMintedNoTradePath() public {
        addL2Pools();
        // nUSD -> USDC is not supported (USDC.e is the correct destination token)
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nusd}),
            usdc,
            amount
        );
        assertNoPathSwapQuery(query, usdc);
    }

    function testGetAmountOutMintedNoTradePathToETH() public {
        addL2Pools();
        // nUSD -> ETH is not supported
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nusd}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    function testGetAmountOutMintedNoWhitelistedPool() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH -> WETH is possible, but not whitelisted
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            weth,
            amount
        );
        assertNoPathSwapQuery(query, weth);
    }

    function testGetAmountOutMintedNoWhitelistedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH -> WETH -> ETH is possible, but not whitelisted
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ══════════════════════════════ (3A) SWAP FOUND USING ORIGIN-ONLY DEFAULT POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as the origin-only pools could not be used on destination requests.

    function testGetAmountOutMintedSwapFoundOriginOnlyDefaultPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nUSD -> USDT is possible, but only via origin-only pool
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nusd}),
            usdt,
            amount
        );
        assertNoPathSwapQuery(query, usdt);
    }

    function testGetAmountOutMintedSwapFoundOriginOnlyDefaultPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH -> ETH is possible, but only via origin-only pool
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ═══════════════════════════════ (3B) SWAP FOUND USING ORIGIN-ONLY LINKED POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as the origin-only pools could not be used on destination requests.

    function testGetAmountOutMintedSwapFoundOriginOnlyLinkedPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // nUSD -> USDT is possible, but only via origin-only pool
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nusd}),
            usdt,
            amount
        );
        assertNoPathSwapQuery(query, usdt);
    }

    function testGetAmountOutMintedSwapFoundOriginOnlyLinkedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH -> ETH is possible, but only via origin-only pool
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ═════════════════════════════════ (3C) SWAP FOUND USING BRIDGE DEFAULT POOL ═════════════════════════════════════

    // These tests result in valid SwapQuery, as the bridge pools are used on destination requests.

    function testGetAmountOutMintedSwapFoundBridgeDefaultPool() public {
        addL2Pools();
        // nETH(0) -> WETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            weth,
            amount
        );
        assertPathFoundSwapQuery(query, weth, expectedAmountOut, getSwapParams(poolNethWeth, 0, 1));
    }

    function testGetAmountOutMintedSwapFoundBridgeDefaultPoolToETH() public {
        addL2Pools();
        // nETH(0) -> ETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertPathFoundSwapQuery(
            query,
            UniversalTokenLib.ETH_ADDRESS,
            expectedAmountOut,
            getSwapParams(poolNethWeth, 0, 1)
        );
    }

    // ═════════════════════════════════ (3D) SWAP FOUND USING BRIDGE LINKED POOL ══════════════════════════════════════

    // These tests result in valid SwapQuery, as the bridge pools are used on destination requests.

    function testGetAmountOutMintedSwapFoundBridgeLinkedPool() public {
        addL2Pools();
        // nUSD(0) -> USDC.e (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nusd}),
            usdcE,
            amount
        );
        assertPathFoundSwapQuery(query, usdcE, expectedAmountOut, getSwapParams(linkedPoolNusd, 0, 1));
    }

    function testGetAmountOutMintedSwapFoundBridgeLinkedPoolToETH() public {
        addL2Pools();
        address pool = adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // nETH(0) -> ETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertPathFoundSwapQuery(query, UniversalTokenLib.ETH_ADDRESS, expectedAmountOut, getSwapParams(pool, 0, 1));
    }

    // ════════════════════════════════════════════ (3E) ADD LIQUIDITY ═════════════════════════════════════════════════

    // These tests result in empty SwapQuery, as add liquidity is not supported on destination requests.

    function testGetAmountOutMintedAddLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: USDC -> nUSD
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusUsdc}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
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
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusUsdc}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    // LinkedPools don't support Add Liquidity

    function testGetAmountOutMintedAddLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        // Linked Nexus pool is whitelisted for USDC in the next call
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: USDC -> nUSD
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusUsdc}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    function testGetAmountOutMintedAddLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: USDC -> nUSD
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusUsdc}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    // ═══════════════════════════════════════════ (3F) REMOVE LIQUIDITY ═══════════════════════════════════════════════

    // These tests result in empty SwapQuery, as remove liquidity is not supported for minted tokens.

    function testGetAmountOutMintedRemoveLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: nUSD -> USDT
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusNusd}),
            nexusUsdt,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdt);
    }

    function testGetAmountOutMintedRemoveLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: nUSD -> USDT
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusNusd}),
            nexusUsdt,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdt);
    }

    // LinkedPools don't support Remove Liquidity

    function testGetAmountOutMintedRemoveLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusNusd}),
            nexusUsdt,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdt);
    }

    function testGetAmountOutMintedRemoveLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: nexusNusd}),
            nexusUsdt,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdt);
    }

    // ══════════════════════════════════════════════ (3G) HANDLE ETH ══════════════════════════════════════════════════

    // These tests result in empty SwapQuery, as handle eth is not supported for minted tokens.

    function testGetAmountOutMintedHandleEthFoundToETH() public {
        addL2Pools();
        // WETH -> ETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskMintedToken, token: weth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }
}
