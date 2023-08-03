// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {ActionLib, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {BasicSwapQuoterV2Test} from "./BasicSwapQuoterV2.t.sol";

// solhint-disable max-states-count
contract SwapQuoterV2GetAmountOutOriginTest is BasicSwapQuoterV2Test {
    // In origin requests actionMask is set to ActionLib.allActions()

    /// Three potential outcomes are available:
    /// 1. `tokenIn` and `tokenOut` represent the same token address (identical tokens).
    /// 2. `tokenIn` and `tokenOut` represent different addresses. No trade path from `tokenIn` to `tokenOut` is found.
    /// 3. `tokenIn` and `tokenOut` represent different addresses. Trade path from `tokenIn` to `tokenOut` is found.

    // ══════════════════════════════════════════════ (1) SAME TOKENS ══════════════════════════════════════════════════

    function testGetAmountOutOriginSameBridgeToken() public {
        addL2Pools();
        // nETH -> nETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: neth}),
            neth,
            amount
        );
        assertSameTokenSwapQuery(query, neth, amount);
    }

    function testGetAmountOutOriginSameNonBridgeToken() public {
        addL2Pools();
        // USDT -> USDT
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: usdt}),
            usdt,
            amount
        );
        assertSameTokenSwapQuery(query, usdt, amount);
    }

    function testGetAmountOutOriginSameETH() public {
        addL2Pools();
        // ETH -> ETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertSameTokenSwapQuery(query, UniversalTokenLib.ETH_ADDRESS, amount);
    }

    // ═════════════════════════════════════════════ (2) NO SWAP FOUND ═════════════════════════════════════════════════

    function testGetAmountOutOriginNoTradePath() public {
        addL2Pools();
        // nUSD -> WETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            weth,
            amount
        );
        assertNoPathSwapQuery(query, weth);
    }

    function testGetAmountOutOriginNoTradePathFromETH() public {
        addL2Pools();
        // ETH -> nUSD
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            nusd,
            amount
        );
        assertNoPathSwapQuery(query, nusd);
    }

    function testGetAmountOutOriginNoTradePathToETH() public {
        addL2Pools();
        // nUSD -> ETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nusd}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertNoPathSwapQuery(query, UniversalTokenLib.ETH_ADDRESS);
    }

    // ══════════════════════════════ (3A) SWAP FOUND USING ORIGIN-ONLY DEFAULT POOL ═══════════════════════════════════

    function testGetAmountOutOriginSwapFoundOriginOnlyDefaultPool() public {
        addL2Pools();
        // USDC.e (0) -> USDT (1)
        uint256 amount = 10**6;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolUsdcEUsdt).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: usdcE}),
            usdt,
            amount
        );
        assertPathFoundSwapQuery(query, usdt, expectedAmountOut, getSwapParams(poolUsdcEUsdt, 0, 1));
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyDefaultPoolFromETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // ETH (1) -> nETH (0)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            neth,
            amount
        );
        assertPathFoundSwapQuery(query, neth, expectedAmountOut, getSwapParams(poolNethWeth, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyDefaultPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH (0) -> ETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: neth}),
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

    // ═══════════════════════════════ (3B) SWAP FOUND USING ORIGIN-ONLY LINKED POOL ═══════════════════════════════════

    function testGetAmountOutOriginSwapFoundOriginOnlyLinkedPool() public {
        addL2Pools();
        // USDC.e (1) -> USDC (0)
        uint256 amount = 10**6;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolUsdcUsdcE).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: usdcE}),
            usdc,
            amount
        );
        assertPathFoundSwapQuery(query, usdc, expectedAmountOut, getSwapParams(linkedPoolUsdc, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyLinkedPoolFromETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // ETH (1) -> nETH (0)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            neth,
            amount
        );
        assertPathFoundSwapQuery(query, neth, expectedAmountOut, getSwapParams(linkedPool, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyLinkedPoolToETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH (0) -> ETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertPathFoundSwapQuery(
            query,
            UniversalTokenLib.ETH_ADDRESS,
            expectedAmountOut,
            getSwapParams(linkedPool, 0, 1)
        );
    }

    // ═════════════════════════════════ (3C) SWAP FOUND USING BRIDGE DEFAULT POOL ═════════════════════════════════════

    function testGetAmountOutOriginSwapFoundBridgeDefaultPool() public {
        addL2Pools();
        // WETH (1) -> nETH (0)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: weth}),
            neth,
            amount
        );
        assertPathFoundSwapQuery(query, neth, expectedAmountOut, getSwapParams(poolNethWeth, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundBridgeDefaultPoolFromETH() public {
        addL2Pools();
        // ETH (1) -> nETH (0)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            neth,
            amount
        );
        assertPathFoundSwapQuery(query, neth, expectedAmountOut, getSwapParams(poolNethWeth, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundBridgeDefaultPoolToETH() public {
        addL2Pools();
        // nETH (0) -> ETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: neth}),
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

    function testGetAmountOutOriginSwapFoundBridgeLinkedPool() public {
        addL2Pools();
        // USDC.e (1) -> nUSD (0)
        uint256 amount = 10**6;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: usdcE}),
            nusd,
            amount
        );
        assertPathFoundSwapQuery(query, nusd, expectedAmountOut, getSwapParams(linkedPoolNusd, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundBridgeLinkedPoolFromETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // ETH (1) -> nETH (0)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            neth,
            amount
        );
        assertPathFoundSwapQuery(query, neth, expectedAmountOut, getSwapParams(linkedPool, 1, 0));
    }

    function testGetAmountOutOriginSwapFoundBridgeLinkedPoolToETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // nETH (0) -> ETH (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amount);
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: neth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertPathFoundSwapQuery(
            query,
            UniversalTokenLib.ETH_ADDRESS,
            expectedAmountOut,
            getSwapParams(linkedPool, 0, 1)
        );
    }

    // ════════════════════════════════════════════ (3E) ADD LIQUIDITY ═════════════════════════════════════════════════

    function testGetAmountOutOriginAddLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: USDT (2) -> nUSD
        uint256 amount = 10**6;
        uint256 expectedAmountOut = DefaultPoolCalc(defaultPoolCalc).calculateAddLiquidity(
            nexusPoolDaiUsdcUsdt,
            toArray(0, 0, amount)
        );
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusUsdt}),
            nexusNusd,
            amount
        );
        assertPathFoundSwapQuery(query, nexusNusd, expectedAmountOut, getAddLiquidityParams(nexusPoolDaiUsdcUsdt, 2));
    }

    function testGetAmountOutOriginAddLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: DAI (0) -> nUSD
        uint256 amount = 10**18;
        uint256 expectedAmountOut = DefaultPoolCalc(defaultPoolCalc).calculateAddLiquidity(
            nexusPoolDaiUsdcUsdt,
            toArray(amount, 0, 0)
        );
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusDai}),
            nexusNusd,
            amount
        );
        assertPathFoundSwapQuery(query, nexusNusd, expectedAmountOut, getAddLiquidityParams(nexusPoolDaiUsdcUsdt, 0));
    }

    // LinkedPools don't support Add Liquidity

    function testGetAmountOutOriginAddLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: USDT (2) -> nUSD
        uint256 amount = 10**6;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusUsdt}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    function testGetAmountOutOriginAddLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: DAI (0) -> nUSD
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusDai}),
            nexusNusd,
            amount
        );
        assertNoPathSwapQuery(query, nexusNusd);
    }

    // ═══════════════════════════════════════════ (3F) REMOVE LIQUIDITY ═══════════════════════════════════════════════

    function testGetAmountOutOriginRemoveLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: nUSD -> USDC (1)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(nexusPoolDaiUsdcUsdt).calculateRemoveLiquidityOneToken(
            amount,
            1
        );
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusNusd}),
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

    function testGetAmountOutOriginRemoveLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: nUSD -> DAI (0)
        uint256 amount = 10**18;
        uint256 expectedAmountOut = IDefaultExtendedPool(nexusPoolDaiUsdcUsdt).calculateRemoveLiquidityOneToken(
            amount,
            0
        );
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusNusd}),
            nexusDai,
            amount
        );
        assertPathFoundSwapQuery(query, nexusDai, expectedAmountOut, getRemoveLiquidityParams(nexusPoolDaiUsdcUsdt, 0));
    }

    // LinkedPools don't support Remove Liquidity

    function testGetAmountOutOriginRemoveLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: nUSD -> USDC (1)
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusNusd}),
            nexusUsdc,
            amount
        );
        assertNoPathSwapQuery(query, nexusUsdc);
    }

    function testGetAmountOutOriginRemoveLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: nUSD -> DAI (0)
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: nexusNusd}),
            nexusDai,
            amount
        );
        assertNoPathSwapQuery(query, nexusDai);
    }

    // ══════════════════════════════════════════════ (3G) HANDLE ETH ══════════════════════════════════════════════════

    function testGetAmountOutOriginHandleEthFoundFromETH() public {
        addL2Pools();
        // ETH -> WETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: UniversalTokenLib.ETH_ADDRESS}),
            weth,
            amount
        );
        assertPathFoundSwapQuery(query, weth, amount, getHandleEthParams());
    }

    function testGetAmountOutOriginHandleEthFoundToETH() public {
        addL2Pools();
        // WETH -> ETH
        uint256 amount = 10**18;
        SwapQuery memory query = quoter.getAmountOut(
            LimitedToken({actionMask: ActionLib.allActions(), token: weth}),
            UniversalTokenLib.ETH_ADDRESS,
            amount
        );
        assertPathFoundSwapQuery(query, UniversalTokenLib.ETH_ADDRESS, amount, getHandleEthParams());
    }
}
