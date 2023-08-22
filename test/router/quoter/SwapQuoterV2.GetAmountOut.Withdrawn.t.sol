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

    // ═══════════════════════════════ GENERIC DESTINATION CHECKS: WITHDRAWN TOKENS ════════════════════════════════════

    function checkWithdrawnSameToken(address tokenIn) public {
        uint256 amount = 10**18;
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: maskWithdrawnToken, token: tokenIn});
        address tokenOut = tokenIn;
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amount);
        assertSameTokenSwapQuery(query, tokenOut, amount);
    }

    function checkWithdrawnNoTradePathExists(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public {
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: maskWithdrawnToken, token: tokenIn});
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amountIn);
        assertNoPathSwapQuery(query, tokenOut);
    }

    function checkWithdrawnTradePathFound(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        bytes memory expectedParams
    ) public {
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: maskWithdrawnToken, token: tokenIn});
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amountIn);
        assertPathFoundSwapQuery(query, tokenOut, expectedAmountOut, expectedParams);
    }

    // ══════════════════════════════════════════════ (1) SAME TOKENS ══════════════════════════════════════════════════

    function testGetAmountOutWithdrawnSameBridgeToken() public {
        addL1Pool();
        // nexusNusd -> nexusNusd
        checkWithdrawnSameToken(nexusNusd);
    }

    // ═════════════════════════════════════════════ (2) NO SWAP FOUND ═════════════════════════════════════════════════

    function testGetAmountOutWithdrawnNoTradePath() public {
        addL1Pool();
        // nexusNusd -> USDC is not supported (nexusUSDC is the correct destination token)
        checkWithdrawnNoTradePathExists(nexusNusd, usdc, 10**18);
    }

    function testGetAmountOutWithdrawnNoTradePathToETH() public {
        addL1Pool();
        // nexusNusd -> ETH is not supported
        checkWithdrawnNoTradePathExists(nexusNusd, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    function testGetAmountOutWithdrawnNoWhitelistedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nexusNusd -> nexusUSDC is possible, but not whitelisted
        checkWithdrawnNoTradePathExists(nexusNusd, nexusUsdc, 10**18);
    }

    function testGetAmountOutWithdrawnNoWhitelistedPoolToETH() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nexusNusd -> ETH is not supported, and no whitelisted pool exist
        checkWithdrawnNoTradePathExists(nexusNusd, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ══════════════════════════════ (3A) SWAP FOUND USING ORIGIN-ONLY DEFAULT POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyDefaultPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nUSD -> USDT is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(nusd, usdt, 10**18);
    }

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyDefaultPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ═══════════════════════════════ (3B) SWAP FOUND USING ORIGIN-ONLY LINKED POOL ═══════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyLinkedPool() public {
        addL2Pools();
        adjustNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // nUSD -> USDT is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(nusd, usdt, 10**18);
    }

    function testGetAmountOutWithdrawnSwapFoundOriginOnlyLinkedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ═════════════════════════════════ (3C) SWAP FOUND USING BRIDGE DEFAULT POOL ═════════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundBridgeDefaultPool() public {
        addL2Pools();
        // nETH -> WETH is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(neth, weth, 10**18);
    }

    function testGetAmountOutWithdrawnSwapFoundBridgeDefaultPoolToETH() public {
        addL2Pools();
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ═════════════════════════════════ (3D) SWAP FOUND USING BRIDGE LINKED POOL ══════════════════════════════════════

    // These tests result in empty SwapQuery, as swap is not possible for withdrawn tokens.

    function testGetAmountOutWithdrawnSwapFoundBridgeLinkedPool() public {
        addL2Pools();
        // nUSD -> USDC.e is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(nusd, usdcE, 10**18);
    }

    function testGetAmountOutWithdrawnSwapFoundBridgeLinkedPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // nETH -> ETH is possible, but swap is not supported for withdrawn tokens
        checkWithdrawnNoTradePathExists(neth, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ════════════════════════════════════════════ (3E) ADD LIQUIDITY ═════════════════════════════════════════════════

    // These tests result in empty SwapQuery, as add liquidity is not supported on destination requests.

    function testGetAmountOutWithdrawnAddLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // nexusUsdc -> nexusNusd is only possible for origin requests
        checkWithdrawnNoTradePathExists(nexusUsdc, nexusNusd, 10**6);
    }

    function testGetAmountOutWithdrawnAddLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // nexusUsdc -> nexusNusd is only possible for origin requests
        checkWithdrawnNoTradePathExists(nexusUsdc, nexusNusd, 10**6);
    }

    // LinkedPools don't support Add Liquidity

    function testGetAmountOutWithdrawnAddLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: USDT (2) -> nUSD
        checkWithdrawnNoTradePathExists(nexusUsdt, nexusNusd, 10**6);
    }

    function testGetAmountOutWithdrawnAddLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: DAI (0) -> nUSD
        checkWithdrawnNoTradePathExists(nexusDai, nexusNusd, 10**18);
    }

    // ═══════════════════════════════════════════ (3F) REMOVE LIQUIDITY ═══════════════════════════════════════════════

    function testGetAmountOutWithdrawnRemoveLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: nUSD -> USDC (1)
        uint256 amountIn = 10**18;
        checkWithdrawnTradePathFound({
            tokenIn: nexusNusd,
            tokenOut: nexusUsdc,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(nexusPoolDaiUsdcUsdt).calculateRemoveLiquidityOneToken(amountIn, 1),
            expectedParams: getRemoveLiquidityParams(nexusPoolDaiUsdcUsdt, 1)
        });
    }

    // Empty SwapQuery, as origin-only pools are not supported for destination requests
    function testGetAmountOutWithdrawnRemoveLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: nUSD -> USDC (1)
        checkWithdrawnNoTradePathExists(nexusNusd, nexusUsdc, 10**18);
    }

    // LinkedPools don't support Remove Liquidity

    function testGetAmountOutWithdrawnRemoveLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        checkWithdrawnNoTradePathExists(nexusNusd, nexusUsdt, 10**18);
    }

    function testGetAmountOutWithdrawnRemoveLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: nUSD -> USDT
        checkWithdrawnNoTradePathExists(nexusNusd, nexusUsdt, 10**18);
    }

    // ══════════════════════════════════════════════ (3G) HANDLE ETH ══════════════════════════════════════════════════

    function testGetAmountOutWithdrawnHandleEthFoundToETH() public {
        addL2Pools();
        // WETH -> ETH
        uint256 amountIn = 10**18;
        checkWithdrawnTradePathFound({
            tokenIn: weth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: amountIn,
            expectedParams: getHandleEthParams()
        });
    }
}
