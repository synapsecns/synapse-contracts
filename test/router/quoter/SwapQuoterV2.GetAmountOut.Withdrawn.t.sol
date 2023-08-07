// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {Action, ActionLib, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";

import {BasicSwapQuoterV2Test} from "./BasicSwapQuoterV2.t.sol";

contract SwapQuoterV2GetAmountOutWithdrawnTest is BasicSwapQuoterV2Test {
    // In destination requests actionMask is set to
    // - For withdrawn tokens: Action.RemoveLiquidity | Action.HandleEth

    uint256 public maskWithdrawnToken = Action.RemoveLiquidity.mask(Action.HandleEth);

    /// Three potential outcomes are available:
    /// 1. `tokenIn` and `tokenOut` represent the same token address (identical tokens).
    /// 2. `tokenIn` and `tokenOut` represent different addresses. No trade path from `tokenIn` to `tokenOut` is found.
    /// 3. `tokenIn` and `tokenOut` represent different addresses. Trade path from `tokenIn` to `tokenOut` is found.

    // ══════════════════════════════════════════════ (1) SAME TOKENS ══════════════════════════════════════════════════

    function testGetAmountOutWithdrawnSameBridgeToken() public {
        addL1Pool();
        // nexusNusd -> nexusNusd
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            nexusNusd,
            amount
        );
        assertSameTokenSwapQuery(query, nexusNusd, amount);
    }

    // ═════════════════════════════════════════════ (2) NO SWAP FOUND ═════════════════════════════════════════════════

    function testGetAmountOutWithdrawnNoTradePath() public {
        addL1Pool();
        // nexusNusd -> USDC is not supported (nexusUSDC is the correct destination token)
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            usdc,
            amount
        );
        assertNoPathSwapQuery(query, usdc);
    }

    function testGetAmountOutWithdrawnNoTradePathToETH() public {
        addL1Pool();
        // nexusNusd -> ETH is not supported
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    function testGetAmountOutWithdrawnNoWhitelistedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nexusNusd -> nexusUSDC is possible, but not whitelisted
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            nexusUsdc,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdc);
    }

    function testGetAmountOutWithdrawnNoWhitelistedPoolToETH() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nexusNusd -> ETH is not supported, and no whitelisted pool exist
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ══════════════════════════════ (3A) SWAP FOUND USING ORIGIN-ONLY DEFAULT POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyDefaultPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nUSD -> USDT is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nusd}),
            usdt,
            amount
        );
        assertNoPathSwapQuery(query, usdt);
    }

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyDefaultPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ═══════════════════════════════ (3B) SWAP FOUND USING ORIGIN-ONLY LINKED POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyLinkedPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // nUSD -> USDT is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nusd}),
            usdt,
            amount
        );
        assertNoPathSwapQuery(query, usdt);
    }

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyLinkedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ═════════════════════════════════ (3C) SWAP FOUND USING BRIDGE DEFAULT POOL ═════════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundBridgeDefaultPool() public {
        addL2Pools();
        // nETH -> WETH is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: neth}),
            weth,
            amount
        );
        assertNoPathSwapQuery(query, weth);
    }

    function testGetAmountOutWithdrawnSwapFoundBridgeDefaultPoolToETH() public {
        addL2Pools();
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ═════════════════════════════════ (3D) SWAP FOUND USING BRIDGE LINKED POOL ══════════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundBridgeLinkedPool() public {
        addL2Pools();
        // nUSD -> USDC.e is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nusd}),
            usdcE,
            amount
        );
        assertNoPathSwapQuery(query, usdcE);
    }

    function testGetAmountOutWithdrawnSwapFoundBridgeLinkedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ════════════════════════════════════════════ (3E) ADD LIQUIDITY ═════════════════════════════════════════════════

    // These tests result in empty SwapQuery, as add liquidity is not supported on destination requests.

    function testGetAmountOutWithdrawnAddLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nexusUsdc -> nexusNusd is only possible for origin requests
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusUsdc}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    function testGetAmountOutWithdrawnAddLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // nexusUsdc -> nexusNusd is only possible for origin requests
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusUsdc}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    // LinkedPools don't support Add Liquidity

    function testGetAmountOutWithdrawnAddLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: USDT (2) -> nUSD
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusUsdt}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    function testGetAmountOutWithdrawnAddLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: DAI (0) -> nUSD
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusDai}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    // ═══════════════════════════════════════════ (3F) REMOVE LIQUIDITY ═══════════════════════════════════════════════

    function testGetAmountOutWithdrawnRemoveLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: nUSD -> USDC (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(nexusPoolDaiUsdcUsdt).calculateRemoveLiquidityOneToken(
            amount,
            1
        );
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            nexusUsdc,
            amount
        );
        assertPathFoundSwapQuery(
            query,
            nexusUsdc,
            expectedAmountOut,
            getRemoveLiquidityParams(nexusPoolDaiUsdcUsdt, 1)
        );
    }

    // Empty SwapQuery, as origin-only pools are not supported for destination requests
    function testGetAmountOutWithdrawnRemoveLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: nUSD -> USDC (1)
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            nexusUsdc,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdc);
    }

    // LinkedPools don't support Remove Liquidity

    function testGetAmountOutWithdrawnRemoveLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            nexusUsdt,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdt);
    }

    function testGetAmountOutWithdrawnRemoveLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: nexusNusd}),
            nexusUsdt,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdt);
    }

    // ══════════════════════════════════════════════ (3G) HANDLE ETH ══════════════════════════════════════════════════

    function testGetAmountOutWithdrawnHandleEthFoundToETH() public {
        addL2Pools();
        // WETH -> ETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: maskWithdrawnToken, token: weth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertPathFoundSwapQuery(query, UniversalTokenLib.ETH_ADDRESS, amount, getHandleEthParams());
    }
}
