// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {ActionLib, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../contracts/router/libs/UniversalToken.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {BasicSwapQuoterV2Test} from "./BasicSwapQuoterV2.t.sol";

contract SwapQuoterV2GetAmountOutOriginTest is BasicSwapQuoterV2Test {
    // In origin requests actionMask is set to ActionLib.allActions()

    /// Three potential outcomes are available:
    /// 1. `tokenIn` and `tokenOut` represent the same token address (identical tokens).
    /// 2. `tokenIn` and `tokenOut` represent different addresses. No trade path from `tokenIn` to `tokenOut` is found.
    /// 3. `tokenIn` and `tokenOut` represent different addresses. Trade path from `tokenIn` to `tokenOut` is found.

    // ═══════════════════════════════════════════ GENERIC ORIGIN CHECKS ═══════════════════════════════════════════════

    function checkOriginSameToken(address tokenIn) public {
        uint256 amount = 10**18;
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: ActionLib.allActions(), token: tokenIn});
        address tokenOut = tokenIn;
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amount);
        assertSameTokenSwapQuery(query, tokenOut, amount);
    }

    function checkOriginNoTradePathExists(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public {
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: ActionLib.allActions(), token: tokenIn});
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amountIn);
        assertNoPathSwapQuery(query, tokenOut);
    }

    function checkOriginTradePathFound(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        bytes memory expectedParams
    ) public {
        LimitedToken memory tokenIn_ = LimitedToken({actionMask: ActionLib.allActions(), token: tokenIn});
        SwapQuery memory query = quoter.getAmountOut(tokenIn_, tokenOut, amountIn);
        assertPathFoundSwapQuery(query, tokenOut, expectedAmountOut, expectedParams);
    }

    // ══════════════════════════════════════════════ (1) SAME TOKENS ══════════════════════════════════════════════════

    function testGetAmountOutOriginSameBridgeToken() public {
        addL2Pools();
        // nETH -> nETH
        checkOriginSameToken(neth);
    }

    function testGetAmountOutOriginSameNonBridgeToken() public {
        addL2Pools();
        // USDT -> USDT
        checkOriginSameToken(usdt);
    }

    function testGetAmountOutOriginSameETH() public {
        addL2Pools();
        // ETH -> ETH
        checkOriginSameToken(UniversalTokenLib.ETH_ADDRESS);
    }

    // ═════════════════════════════════════════════ (2) NO SWAP FOUND ═════════════════════════════════════════════════

    function testGetAmountOutOriginNoTradePath() public {
        addL2Pools();
        // nUSD -> WETH
        checkOriginNoTradePathExists(nusd, weth, 10**18);
    }

    function testGetAmountOutOriginNoTradePathFromETH() public {
        addL2Pools();
        // ETH -> nUSD
        checkOriginNoTradePathExists(UniversalTokenLib.ETH_ADDRESS, nusd, 10**18);
    }

    function testGetAmountOutOriginNoTradePathToETH() public {
        addL2Pools();
        // nUSD -> ETH
        checkOriginNoTradePathExists(nusd, UniversalTokenLib.ETH_ADDRESS, 10**18);
    }

    // ══════════════════════════════ (3A) SWAP FOUND USING ORIGIN-ONLY DEFAULT POOL ═══════════════════════════════════

    function testGetAmountOutOriginSwapFoundOriginOnlyDefaultPool() public {
        addL2Pools();
        // USDC.e (0) -> USDT (1)
        uint256 amountIn = 10**6;
        checkOriginTradePathFound({
            tokenIn: usdcE,
            tokenOut: usdt,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolUsdcEUsdt).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(poolUsdcEUsdt, 0, 1)
        });
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyDefaultPoolFromETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // ETH (1) -> nETH (0)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: UniversalTokenLib.ETH_ADDRESS,
            tokenOut: neth,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyDefaultPoolToETH() public {
        addL2Pools();
        adjustNethPool({makeOnlyOrigin: true, makeLinked: false});
        // nETH (0) -> ETH (1)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: neth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 0, 1)
        });
    }

    // ═══════════════════════════════ (3B) SWAP FOUND USING ORIGIN-ONLY LINKED POOL ═══════════════════════════════════

    function testGetAmountOutOriginSwapFoundOriginOnlyLinkedPool() public {
        addL2Pools();
        // USDC.e (1) -> USDC (0)
        uint256 amountIn = 10**6;
        checkOriginTradePathFound({
            tokenIn: usdcE,
            tokenOut: usdc,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolUsdcUsdcE).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(linkedPoolUsdc, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyLinkedPoolFromETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // ETH (1) -> nETH (0)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: UniversalTokenLib.ETH_ADDRESS,
            tokenOut: neth,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(linkedPool, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundOriginOnlyLinkedPoolToETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: true, makeLinked: true});
        // nETH (0) -> ETH (1)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: neth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(linkedPool, 0, 1)
        });
    }

    // ═════════════════════════════════ (3C) SWAP FOUND USING BRIDGE DEFAULT POOL ═════════════════════════════════════

    function testGetAmountOutOriginSwapFoundBridgeDefaultPool() public {
        addL2Pools();
        // WETH (1) -> nETH (0)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: weth,
            tokenOut: neth,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundBridgeDefaultPoolFromETH() public {
        addL2Pools();
        // ETH (1) -> nETH (0)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: UniversalTokenLib.ETH_ADDRESS,
            tokenOut: neth,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundBridgeDefaultPoolToETH() public {
        addL2Pools();
        // nETH (0) -> ETH (1)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: neth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(poolNethWeth, 0, 1)
        });
    }

    // ═════════════════════════════════ (3D) SWAP FOUND USING BRIDGE LINKED POOL ══════════════════════════════════════

    function testGetAmountOutOriginSwapFoundBridgeLinkedPool() public {
        addL2Pools();
        // USDC.e (1) -> nUSD (0)
        uint256 amountIn = 10**6;
        checkOriginTradePathFound({
            tokenIn: usdcE,
            tokenOut: nusd,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(linkedPoolNusd, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundBridgeLinkedPoolFromETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // ETH (1) -> nETH (0)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: UniversalTokenLib.ETH_ADDRESS,
            tokenOut: neth,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(1, 0, amountIn),
            expectedParams: getSwapParams(linkedPool, 1, 0)
        });
    }

    function testGetAmountOutOriginSwapFoundBridgeLinkedPoolToETH() public {
        addL2Pools();
        address linkedPool = adjustNethPool({makeOnlyOrigin: false, makeLinked: true});
        // nETH (0) -> ETH (1)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: neth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(poolNethWeth).calculateSwap(0, 1, amountIn),
            expectedParams: getSwapParams(linkedPool, 0, 1)
        });
    }

    // ════════════════════════════════════════════ (3E) ADD LIQUIDITY ═════════════════════════════════════════════════

    function testGetAmountOutOriginAddLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: USDT (2) -> nUSD
        uint256 amountIn = 10**6;
        checkOriginTradePathFound({
            tokenIn: nexusUsdt,
            tokenOut: nexusNusd,
            amountIn: amountIn,
            expectedAmountOut: DefaultPoolCalc(defaultPoolCalc).calculateAddLiquidity(
                nexusPoolDaiUsdcUsdt,
                toArray(0, 0, amountIn)
            ),
            expectedParams: getAddLiquidityParams(nexusPoolDaiUsdcUsdt, 2)
        });
    }

    function testGetAmountOutOriginAddLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: DAI (0) -> nUSD
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: nexusDai,
            tokenOut: nexusNusd,
            amountIn: amountIn,
            expectedAmountOut: DefaultPoolCalc(defaultPoolCalc).calculateAddLiquidity(
                nexusPoolDaiUsdcUsdt,
                toArray(amountIn, 0, 0)
            ),
            expectedParams: getAddLiquidityParams(nexusPoolDaiUsdcUsdt, 0)
        });
    }

    // LinkedPools don't support Add Liquidity

    function testGetAmountOutOriginAddLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: USDT (2) -> nUSD
        checkOriginNoTradePathExists(nexusUsdt, nexusNusd, 10**6);
    }

    function testGetAmountOutOriginAddLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: DAI (0) -> nUSD
        checkOriginNoTradePathExists(nexusDai, nexusNusd, 10**18);
    }

    // ═══════════════════════════════════════════ (3F) REMOVE LIQUIDITY ═══════════════════════════════════════════════

    function testGetAmountOutOriginRemoveLiquidityFoundOriginOnlyDefaultPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: false});
        // Nexus pool: nUSD -> USDC (1)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: nexusNusd,
            tokenOut: nexusUsdc,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(nexusPoolDaiUsdcUsdt).calculateRemoveLiquidityOneToken(amountIn, 1),
            expectedParams: getRemoveLiquidityParams(nexusPoolDaiUsdcUsdt, 1)
        });
    }

    function testGetAmountOutOriginRemoveLiquidityFoundBridgeDefaultPool() public {
        addL1Pool();
        // Nexus pool: nUSD -> DAI (0)
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: nexusNusd,
            tokenOut: nexusDai,
            amountIn: amountIn,
            expectedAmountOut: IDefaultExtendedPool(nexusPoolDaiUsdcUsdt).calculateRemoveLiquidityOneToken(amountIn, 0),
            expectedParams: getRemoveLiquidityParams(nexusPoolDaiUsdcUsdt, 0)
        });
    }

    // LinkedPools don't support Remove Liquidity

    function testGetAmountOutOriginRemoveLiquidityNotFoundOriginOnlyLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: true, makeLinked: true});
        // Nexus pool: nUSD -> USDC (1)
        checkOriginNoTradePathExists(nexusNusd, nexusUsdc, 10**18);
    }

    function testGetAmountOutOriginRemoveLiquidityNotFoundBridgeLinkedPool() public {
        addL1Pool();
        adjustNexusNusdPool({makeOnlyOrigin: false, makeLinked: true});
        // Nexus pool: nUSD -> DAI (0)
        checkOriginNoTradePathExists(nexusNusd, nexusDai, 10**18);
    }

    // ══════════════════════════════════════════════ (3G) HANDLE ETH ══════════════════════════════════════════════════

    function testGetAmountOutOriginHandleEthFoundFromETH() public {
        addL2Pools();
        // ETH -> WETH
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: UniversalTokenLib.ETH_ADDRESS,
            tokenOut: weth,
            amountIn: amountIn,
            expectedAmountOut: amountIn,
            expectedParams: getHandleEthParams()
        });
    }

    function testGetAmountOutOriginHandleEthFoundToETH() public {
        addL2Pools();
        // WETH -> ETH
        uint256 amountIn = 10**18;
        checkOriginTradePathFound({
            tokenIn: weth,
            tokenOut: UniversalTokenLib.ETH_ADDRESS,
            amountIn: amountIn,
            expectedAmountOut: amountIn,
            expectedParams: getHandleEthParams()
        });
    }
}
