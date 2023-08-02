// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../contracts/router/interfaces/IDefaultExtendedPool.sol";
import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";
import {Pool, PoolToken} from "../../../contracts/router/libs/Structs.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockWETH} from "../mocks/MockWETH.sol";
import {PoolUtils08} from "../../utils/PoolUtils08.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {console2} from "forge-std/Test.sol";

// solhint-disable max-states-count
contract SwapQuoterV2Test is PoolUtils08 {
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

    function testSetup() public {
        assertEq(quoter.synapseRouter(), synapseRouter);
        assertEq(quoter.defaultPoolCalc(), defaultPoolCalc);
        assertEq(quoter.weth(), weth);
        assertEq(quoter.owner(), owner);
    }

    // ═════════════════════════════════════════ TESTS: SET SYNAPSE ROUTER ═════════════════════════════════════════════

    function testSetSynapseRouterUpdatesSynapseRouter() public {
        address newSynapseRouter = makeAddr("NewSynapseRouter");
        vm.prank(owner);
        quoter.setSynapseRouter(newSynapseRouter);
        assertEq(quoter.synapseRouter(), newSynapseRouter);
    }

    function testSetSynapseRouterRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        quoter.setSynapseRouter(address(1));
    }

    // ═════════════════════════════════════════════ TESTS: ADD POOLS ══════════════════════════════════════════════════

    function testAddPoolsAddsOriginDefaultPools() public {
        addL2Pools();
        // Should return origin-only Default Pools
        address[] memory defaultPools = quoter.getDefaultPools();
        assertEq(defaultPools.length, 1);
        assertEq(defaultPools[0], poolUsdcEUsdt);
    }

    function testAddPoolsAddsOriginLinkedPools() public {
        addL2Pools();
        // Should return origin-only Linked Pools
        address[] memory linkedPools = quoter.getLinkedPools();
        assertEq(linkedPools.length, 1);
        assertEq(linkedPools[0], linkedPoolUsdc);
    }

    function testAddPoolsAddsBridgePools() public {
        addL2Pools();
        // Should return bridge pools
        SwapQuoterV2.BridgePool[] memory bridgePools = quoter.getBridgePools();
        assertEq(bridgePools.length, 2);
        assertEqual(bridgePools[0], getBridgeDefaultPool());
        assertEqual(bridgePools[1], getBridgeLinkedPool());
    }

    function testAddPoolsAddsAllPools() public {
        addL2Pools();
        // Should return all pools
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 4);
        assertEq(quoter.poolsAmount(), 4);
        // Order of pools: origin-only Default Pools, origin-only Linked Pools, bridge pools
        checkPoolData(pools[0], poolUsdcEUsdt);
        checkPoolData(pools[1], linkedPoolUsdc);
        checkPoolData(pools[2], poolNethWeth);
        checkPoolData(pools[3], linkedPoolNusd);
    }

    function testAddPoolsRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        quoter.addPools(new SwapQuoterV2.BridgePool[](0));
    }

    function testAddPoolsRevertsWhenOriginDefaultPoolAlreadyAdded() public {
        addL2Pools();
        vm.expectRevert("Pool has been added before");
        vm.prank(owner);
        quoter.addPools(toArray(getOriginDefaultPool()));
    }

    function testAddPoolsRevertsWhenOriginLinkedPoolAlreadyAdded() public {
        addL2Pools();
        vm.expectRevert("Pool has been added before");
        vm.prank(owner);
        quoter.addPools(toArray(getOriginLinkedPool()));
    }

    function testAddPoolsRevertsWhenBridgeDefaultPoolAlreadyAdded() public {
        addL2Pools();
        vm.expectRevert("Pool has been added before");
        vm.prank(owner);
        quoter.addPools(toArray(getBridgeDefaultPool()));
    }

    function testAddPoolsRevertsWhenBridgeLinkedPoolAlreadyAdded() public {
        addL2Pools();
        vm.expectRevert("Pool has been added before");
        vm.prank(owner);
        quoter.addPools(toArray(getBridgeLinkedPool()));
    }

    function testAddPoolsReplacesBridgePool() public {
        addL2Pools();
        // Replace nUSD Linked Pool with Default Pool
        SwapQuoterV2.BridgePool memory replacement = replaceBridgePool();
        // Should return bridge pools with replaced nUSD pool
        SwapQuoterV2.BridgePool[] memory bridgePools = quoter.getBridgePools();
        assertEq(bridgePools.length, 2);
        assertEqual(bridgePools[0], getBridgeDefaultPool());
        assertEqual(bridgePools[1], replacement);
        // Should return all pools with replaced nUSD pool
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 4);
        assertEq(quoter.poolsAmount(), 4);
        checkPoolData(pools[0], poolUsdcEUsdt);
        checkPoolData(pools[1], linkedPoolUsdc);
        checkPoolData(pools[2], poolNethWeth);
        checkPoolData(pools[3], poolNusdUsdcEUsdt);
    }

    // ════════════════════════════════════════════ TESTS: REMOVE POOLS ════════════════════════════════════════════════

    function testRemovePoolsRemovesOriginDefaultPools() public {
        addL2Pools();
        // Remove origin-only Default Pools
        vm.prank(owner);
        quoter.removePools(toArray(getOriginDefaultPool()));
        // Should return no origin-only Default Pools
        address[] memory defaultPools = quoter.getDefaultPools();
        assertEq(defaultPools.length, 0);
        // Should return all pools except origin-only Default Pools
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 3);
        assertEq(quoter.poolsAmount(), 3);
        // Order of pools: origin-only Linked Pools, bridge pools
        checkPoolData(pools[0], linkedPoolUsdc);
        checkPoolData(pools[1], poolNethWeth);
        checkPoolData(pools[2], linkedPoolNusd);
    }

    function testRemovePoolsRemovesOriginLinkedPools() public {
        addL2Pools();
        // Remove origin-only Linked Pools
        vm.prank(owner);
        quoter.removePools(toArray(getOriginLinkedPool()));
        // Should return no origin-only Linked Pools
        address[] memory linkedPools = quoter.getLinkedPools();
        assertEq(linkedPools.length, 0);
        // Should return all pools except origin-only Linked Pools
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 3);
        assertEq(quoter.poolsAmount(), 3);
        // Order of pools: origin-only Default Pools, bridge pools
        checkPoolData(pools[0], poolUsdcEUsdt);
        checkPoolData(pools[1], poolNethWeth);
        checkPoolData(pools[2], linkedPoolNusd);
    }

    function testRemovePoolsRemovesBridgeDefaultPools() public {
        addL2Pools();
        // Remove bridge Default Pools
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeDefaultPool()));
        // Should return no bridge Default Pools
        SwapQuoterV2.BridgePool[] memory bridgePools = quoter.getBridgePools();
        assertEq(bridgePools.length, 1);
        assertEqual(bridgePools[0], getBridgeLinkedPool());
        // Should return all pools except bridge Default Pools
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 3);
        assertEq(quoter.poolsAmount(), 3);
        // Order of pools: origin-only Default Pools, origin-only Linked Pools, bridge Linked Pools
        checkPoolData(pools[0], poolUsdcEUsdt);
        checkPoolData(pools[1], linkedPoolUsdc);
        checkPoolData(pools[2], linkedPoolNusd);
    }

    function testRemovePoolsRemovesBridgeLinkedPools() public {
        addL2Pools();
        // Remove bridge Linked Pools
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeLinkedPool()));
        // Should return no bridge Linked Pools
        SwapQuoterV2.BridgePool[] memory bridgePools = quoter.getBridgePools();
        assertEq(bridgePools.length, 1);
        assertEqual(bridgePools[0], getBridgeDefaultPool());
        // Should return all pools except bridge Linked Pools
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 3);
        assertEq(quoter.poolsAmount(), 3);
        // Order of pools: origin-only Default Pools, origin-only Linked Pools, bridge Default Pools
        checkPoolData(pools[0], poolUsdcEUsdt);
        checkPoolData(pools[1], linkedPoolUsdc);
        checkPoolData(pools[2], poolNethWeth);
    }

    function testRemovePoolsRemovesBridgePools() public {
        addL2Pools();
        // Remove bridge pools
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeDefaultPool(), getBridgeLinkedPool()));
        // Should return no bridge pools
        SwapQuoterV2.BridgePool[] memory bridgePools = quoter.getBridgePools();
        assertEq(bridgePools.length, 0);
        // Should return all pools except bridge pools
        Pool[] memory pools = quoter.allPools();
        assertEq(pools.length, 2);
        assertEq(quoter.poolsAmount(), 2);
        // Order of pools: origin-only Default Pools, origin-only Linked Pools
        checkPoolData(pools[0], poolUsdcEUsdt);
        checkPoolData(pools[1], linkedPoolUsdc);
    }

    function testRemovePoolsRevertsWhenOriginDefaultPoolUnknown() public {
        addL2Pools();
        vm.prank(owner);
        quoter.removePools(toArray(getOriginDefaultPool()));
        vm.expectRevert("Unknown pool");
        vm.prank(owner);
        quoter.removePools(toArray(getOriginDefaultPool()));
    }

    function testRemovePoolsRevertsWhenOriginLinkedPoolUnknown() public {
        addL2Pools();
        vm.prank(owner);
        quoter.removePools(toArray(getOriginLinkedPool()));
        vm.expectRevert("Unknown pool");
        vm.prank(owner);
        quoter.removePools(toArray(getOriginLinkedPool()));
    }

    function testRemovePoolsRevertsWhenBridgeDefaultPoolUnknown() public {
        addL2Pools();
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeDefaultPool()));
        vm.expectRevert("Unknown pool");
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeDefaultPool()));
    }

    function testRemovePoolsRevertsWhenBridgeLinkedPoolUnknown() public {
        addL2Pools();
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeLinkedPool()));
        vm.expectRevert("Unknown pool");
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeLinkedPool()));
    }

    function testRemovePoolsRevertsWhenBridgePoolReplaced() public {
        addL2Pools();
        // Replace nUSD Linked Pool with Default Pool
        replaceBridgePool();
        vm.expectRevert("Unknown pool");
        vm.prank(owner);
        quoter.removePools(toArray(getBridgeLinkedPool()));
    }

    // ═════════════════════════════════════ TESTS: ARBITRARY POOL INSPECTION ══════════════════════════════════════════

    // Note: no pools are added, Quoter is supposed inspect arbitrary pools

    function testCalculateAddLiquidity() public {
        // Test quote for adding liquidity to nUSD/USDC.e/USDT pool
        // nUSD: 10, USDC.e: 5, USDT: 50
        uint256[] memory amounts = toArray(10 * 10**18, 5 * 10**6, 50 * 10**6);
        uint256 amountOut = quoter.calculateAddLiquidity(poolNusdUsdcEUsdt, amounts);
        // Should be equal to return value from DefaultPoolCalc, which is tested separately
        assertEq(amountOut, DefaultPoolCalc(defaultPoolCalc).calculateAddLiquidity(poolNusdUsdcEUsdt, amounts));
    }

    function testCalculateSwap() public {
        // Test swap quote in nUSD/USDC.e/USDT pool: nUSD -> USDT
        uint256 amountIn = 10**18;
        uint256 amountOut = quoter.calculateSwap(poolNusdUsdcEUsdt, 0, 2, amountIn);
        // Should be equal to pool's calculateSwap
        assertEq(amountOut, IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateSwap(0, 2, amountIn));
    }

    function testCalculateRemoveLiquidity() public {
        // Test remove balanced liquidity quote in nUSD/USDC.e/USDT pool
        uint256 amountIn = 10**18;
        uint256[] memory amounts = quoter.calculateRemoveLiquidity(poolNusdUsdcEUsdt, amountIn);
        uint256[] memory expectedAmounts = IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateRemoveLiquidity(amountIn);
        assertEq(amounts, expectedAmounts);
    }

    function testCalculateWithdrawOneToken() public {
        // Test remove liquidity quote in nUSD/USDC.e/USDT pool -> USDC.e
        uint256 amountIn = 10**18;
        uint256 amountOut = quoter.calculateWithdrawOneToken(poolNusdUsdcEUsdt, amountIn, 1);
        uint256 expectedAmountOut = IDefaultExtendedPool(poolNusdUsdcEUsdt).calculateRemoveLiquidityOneToken(
            amountIn,
            1
        );
        assertEq(amountOut, expectedAmountOut);
    }

    function testPoolInfoDefaultPool() public {
        (uint256 numTokens, address lpToken) = quoter.poolInfo(poolNusdUsdcEUsdt);
        assertEq(numTokens, 3);
        assertEq(lpToken, poolLpToken[poolNusdUsdcEUsdt]);
    }

    function testPoolInfoLinkedPool() public {
        (uint256 numTokens, address lpToken) = quoter.poolInfo(linkedPoolNusd);
        assertEq(numTokens, 3);
        // Linked Pool has no lp token
        assertEq(lpToken, address(0));
    }

    function testPoolTokensDefaultPoolNoWETH() public {
        PoolToken[] memory tokens = quoter.poolTokens(poolNusdUsdcEUsdt);
        assertEq(tokens.length, 3);
        assertEq(tokens[0].token, nusd);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, usdcE);
        assertEq(tokens[1].isWeth, false);
        assertEq(tokens[2].token, usdt);
        assertEq(tokens[2].isWeth, false);
    }

    function testPoolTokensDefaultPoolWithWETH() public {
        PoolToken[] memory tokens = quoter.poolTokens(poolNethWeth);
        assertEq(tokens.length, 2);
        assertEq(tokens[0].token, neth);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, weth);
        assertEq(tokens[1].isWeth, true);
    }

    function testPoolTokensLinkedPoolNoWETH() public {
        PoolToken[] memory tokens = quoter.poolTokens(linkedPoolNusd);
        assertEq(tokens.length, 3);
        assertEq(tokens[0].token, nusd);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, usdcE);
        assertEq(tokens[1].isWeth, false);
        assertEq(tokens[2].token, usdt);
        assertEq(tokens[2].isWeth, false);
    }

    function testPoolTokensLinkedPoolWithWETH() public {
        // Deploy Linked Pool for nETH pool
        address linkedPoolNeth = deployLinkedPool(neth, poolNethWeth);
        PoolToken[] memory tokens = quoter.poolTokens(linkedPoolNeth);
        assertEq(tokens.length, 2);
        assertEq(tokens[0].token, neth);
        assertEq(tokens[0].isWeth, false);
        assertEq(tokens[1].token, weth);
        assertEq(tokens[1].isWeth, true);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function assertEqual(SwapQuoterV2.BridgePool memory pool, SwapQuoterV2.BridgePool memory expected) internal {
        assertEq(pool.bridgeToken, expected.bridgeToken);
        assertEq(uint8(pool.poolType), uint8(expected.poolType));
        assertEq(pool.pool, expected.pool);
    }

    function checkPoolData(Pool memory poolData, address expectedPool) internal {
        address pool = poolData.pool;
        assertEq(pool, expectedPool);
        assertEq(poolData.lpToken, poolLpToken[expectedPool]);
        address[] memory tokens = poolTokens[expectedPool];
        assertEq(poolData.tokens.length, tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(poolData.tokens[i].token, tokens[i]);
            assertEq(poolData.tokens[i].isWeth, tokens[i] == weth);
        }
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
}
