// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";
import {Action, DefaultParams, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../mocks/MockWETH.sol";
import {PoolUtils08} from "../../utils/PoolUtils08.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

// solhint-disable max-states-count
abstract contract BasicSwapQuoterV2Test is PoolUtils08 {
    using SafeERC20 for IERC20;

    SwapQuoterV2 public quoter;
    address public defaultPoolCalc;
    address public synapseRouter;
    address public owner;

    // L2 tokens
    address public neth;
    address public weth;

    address public nusd;
    address public usdc;
    address public usdcE;
    address public usdt;

    // L1 tokens
    address public nexusNusd;
    address public nexusDai;
    address public nexusUsdc;
    address public nexusUsdt;

    // L2 pools
    // bridge pool for nETH
    address public poolNethWeth;
    // bridge pool for nUSD
    address public poolNusdUsdcEUsdt;
    address public linkedPoolNusd;
    // origin-only pool for USDC
    address public poolUsdcUsdcE;
    address public linkedPoolUsdc;
    // origin-only pool
    address public poolUsdcEUsdt;

    // L1 pools
    address public nexusPoolDaiUsdcUsdt;

    function setUp() public virtual override {
        super.setUp();

        synapseRouter = makeAddr("SynapseRouter");
        owner = makeAddr("Owner");

        weth = address(new MockWETH());
        neth = address(new MockERC20("nETH", 18));

        nusd = address(new MockERC20("nUSD", 18));
        usdc = address(new MockERC20("USDC", 6));
        usdcE = address(new MockERC20("USDC.e", 6));
        usdt = address(new MockERC20("USDT", 6));

        nexusDai = address(new MockERC20("ETH DAI", 18));
        nexusUsdc = address(new MockERC20("ETH USDC", 6));
        nexusUsdt = address(new MockERC20("ETH USDT", 6));

        defaultPoolCalc = address(new DefaultPoolCalc());
        quoter = new SwapQuoterV2({
            synapseRouter_: synapseRouter,
            defaultPoolCalc_: defaultPoolCalc,
            weth_: weth,
            owner_: owner
        });

        // Deploy L2 Default Pools
        poolNethWeth = deployDefaultPool("[nETH,WETH]", toArray(neth, weth));
        poolNusdUsdcEUsdt = deployDefaultPool("[nUSD,USDC.e,USDT]", toArray(nusd, usdcE, usdt));
        poolUsdcUsdcE = deployDefaultPool("[USDC,USDC.e]", toArray(usdc, usdcE));
        poolUsdcEUsdt = deployDefaultPool("[USDC.e,USDT]", toArray(usdcE, usdt));
        // Deploy Linked Pools
        linkedPoolNusd = deployLinkedPool(nusd, poolNusdUsdcEUsdt);
        linkedPoolUsdc = deployLinkedPool(usdc, poolUsdcUsdcE);

        // Deploy L1 Default Pool (Nexus)
        nexusPoolDaiUsdcUsdt = deployDefaultPool(
            "[ETH DAI,ETH USDC,ETH USDT]",
            toArray(nexusDai, nexusUsdc, nexusUsdt)
        );
        // Nexus nUSD is the LP token of the Nexus pool
        nexusNusd = getLpToken(nexusPoolDaiUsdcUsdt);

        // Provide initial liquidity to L2 pools
        addLiquidity(poolNethWeth, toArray(100 * 10**18, 101 * 10**18), mintTestTokens);
        addLiquidity(poolNusdUsdcEUsdt, toArray(1000 * 10**18, 1001 * 10**6, 1002 * 10**6), mintTestTokens);
        addLiquidity(poolUsdcUsdcE, toArray(2000 * 10**6, 2001 * 10**6), mintTestTokens);
        addLiquidity(poolUsdcEUsdt, toArray(4000 * 10**6, 4001 * 10**6), mintTestTokens);

        // Provide deep initial liquidity to L1 pool
        addLiquidity(nexusPoolDaiUsdcUsdt, toArray(100000 * 10**18, 100000 * 10**6, 100000 * 10**6), mintTestTokens);
    }

    function addL1Pool() public {
        // nexus pool: [nexusDai,nexusUsdc,nexusUsdt]
        SwapQuoterV2.BridgePool[] memory pools = toArray(getBridgeNexusPool());
        vm.prank(owner);
        quoter.addPools(pools);
    }

    function addL2Pools() public {
        // bridge pool for nETH: [nETH,WETH]
        // bridge pool for nUSD: LinkedPool with [nUSD,USDC.e,USDT]
        // origin-only pool: LinkedPool with [USDC,USDC.e]
        // origin-only pool: [USDC.e,USDT]
        SwapQuoterV2.BridgePool[] memory pools = toArray(
            getBridgeDefaultPool(),
            getBridgeLinkedPool(),
            getOriginLinkedPool(),
            getOriginDefaultPool()
        );
        vm.prank(owner);
        quoter.addPools(pools);
    }

    // Changes configuration of nETH-WETH pool in SwapQuoterV2
    function adjustNethPool(bool makeOnlyOrigin, bool makeLinked) internal returns (address pool) {
        // Remove existing pool first
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeDefaultPool()));
        // Configure new pool
        SwapQuoterV2.PoolType poolType = SwapQuoterV2.PoolType.Default;
        pool = poolNethWeth;
        if (makeLinked) {
            poolType = SwapQuoterV2.PoolType.Linked;
            pool = deployLinkedPool(neth, pool);
        }
        address bridgeToken = makeOnlyOrigin ? address(0) : neth;
        SwapQuoterV2.BridgePool[] memory newPools = toArray(
            SwapQuoterV2.BridgePool({bridgeToken: bridgeToken, poolType: poolType, pool: pool})
        );
        vm.prank(owner);
        quoter.addPools(newPools);
    }

    // Changes configuration of Nexus Nusd pool in SwapQuoterV2
    function adjustNexusNusdPool(bool makeOnlyOrigin, bool makeLinked) internal returns (address pool) {
        // Remove existing pool first
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeNexusPool()));
        // Configure new pool
        SwapQuoterV2.PoolType poolType = SwapQuoterV2.PoolType.Default;
        pool = nexusPoolDaiUsdcUsdt;
        // Linked Pool does not support Add/Remove liquidity, so we use USDC as "bridge token"
        if (makeLinked) {
            poolType = SwapQuoterV2.PoolType.Linked;
            pool = deployLinkedPool(nexusUsdc, pool);
        }
        address bridgeToken = makeOnlyOrigin ? address(0) : nexusUsdc;
        SwapQuoterV2.BridgePool[] memory newPools = toArray(
            SwapQuoterV2.BridgePool({bridgeToken: bridgeToken, poolType: poolType, pool: pool})
        );
        vm.prank(owner);
        quoter.addPools(newPools);
    }

    function replaceBridgePool() public returns (SwapQuoterV2.BridgePool memory replacement) {
        // Replace nUSD Linked Pool with Default Pool
        SwapQuoterV2.BridgePool[] memory newPools = toArray(
            SwapQuoterV2.BridgePool({
                bridgeToken: nusd,
                poolType: SwapQuoterV2.PoolType.Default,
                pool: poolNusdUsdcEUsdt
            })
        );
        vm.prank(owner);
        quoter.addPools(newPools);
        return newPools[0];
    }

    function getBridgeDefaultPool() internal view returns (SwapQuoterV2.BridgePool memory) {
        return
            SwapQuoterV2.BridgePool({bridgeToken: neth, poolType: SwapQuoterV2.PoolType.Default, pool: poolNethWeth});
    }

    function getBridgeLinkedPool() internal view returns (SwapQuoterV2.BridgePool memory) {
        return
            SwapQuoterV2.BridgePool({bridgeToken: nusd, poolType: SwapQuoterV2.PoolType.Linked, pool: linkedPoolNusd});
    }

    function getOriginDefaultPool() internal view returns (SwapQuoterV2.BridgePool memory) {
        return
            SwapQuoterV2.BridgePool({
                bridgeToken: address(0),
                poolType: SwapQuoterV2.PoolType.Default,
                pool: poolUsdcEUsdt
            });
    }

    function getOriginLinkedPool() internal view returns (SwapQuoterV2.BridgePool memory) {
        return
            SwapQuoterV2.BridgePool({
                bridgeToken: address(0),
                poolType: SwapQuoterV2.PoolType.Linked,
                pool: linkedPoolUsdc
            });
    }

    function getBridgeNexusPool() internal view returns (SwapQuoterV2.BridgePool memory) {
        return
            SwapQuoterV2.BridgePool({
                bridgeToken: nexusNusd,
                poolType: SwapQuoterV2.PoolType.Default,
                pool: nexusPoolDaiUsdcUsdt
            });
    }

    function mintTestTokens(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == nexusNusd) {
            // Nexus nUSD can not be just minted, instead tokens received from initial liquidity are used
            // Make sure to setup the Nexus pool with big enough initial liquidity!
            IERC20(token).safeTransfer(to, amount);
        } else {
            MockERC20(token).mint(to, amount);
        }
    }

    // ═════════════════════════════════════════════ SWAP QUERY CHECKS ═════════════════════════════════════════════════

    function assertNoPathSwapQuery(SwapQuery memory query, address tokenOut) internal {
        // tokenOut is set even for empty queries
        assertEq(query.tokenOut, tokenOut);
        // other fields should be empty
        assertEq(query.routerAdapter, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function assertSameTokenSwapQuery(
        SwapQuery memory query,
        address tokenIn,
        uint256 amountIn
    ) internal {
        assertEq(query.tokenOut, tokenIn);
        // routerAdapter should be empty
        assertEq(query.routerAdapter, address(0));
        assertEq(query.minAmountOut, amountIn);
        assertEq(query.deadline, type(uint256).max);
        // Params should be empty
        assertEq(query.rawParams, bytes(""));
    }

    function assertPathFoundSwapQuery(
        SwapQuery memory query,
        address tokenOut,
        uint256 expectedAmountOut,
        bytes memory expectedParams
    ) internal {
        assertEq(query.tokenOut, tokenOut);
        // routerAdapter should SynapseRouter
        assertEq(query.routerAdapter, synapseRouter);
        assertEq(query.minAmountOut, expectedAmountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, expectedParams);
    }

    function getSwapParams(
        address pool,
        uint8 indexFrom,
        uint8 indexTo
    ) internal pure returns (bytes memory) {
        return abi.encode(DefaultParams(Action.Swap, pool, indexFrom, indexTo));
    }

    function getAddLiquidityParams(address pool, uint8 indexFrom) internal pure returns (bytes memory) {
        // indexTo is set to 0xFF
        return abi.encode(DefaultParams(Action.AddLiquidity, pool, indexFrom, 0xFF));
    }

    function getRemoveLiquidityParams(address pool, uint8 indexTo) internal pure returns (bytes memory) {
        // indexFrom is set to 0xFF
        return abi.encode(DefaultParams(Action.RemoveLiquidity, pool, 0xFF, indexTo));
    }

    function getHandleEthParams() internal pure returns (bytes memory) {
        // pool address is zero; indexFrom and indexTo are set to 0xFF
        return abi.encode(DefaultParams(Action.HandleEth, address(0), 0xFF, 0xFF));
    }
}
