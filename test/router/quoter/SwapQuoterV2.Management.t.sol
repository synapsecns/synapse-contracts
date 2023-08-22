// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";
import {Pool} from "../../../contracts/router/libs/Structs.sol";

import {BasicSwapQuoterV2Test} from "./BasicSwapQuoterV2.t.sol";

contract SwapQuoterV2ManagementTest is BasicSwapQuoterV2Test {
    /// @notice Emitted when a pool is added to SwapQuoterV2.
    event PoolAdded(address bridgeToken, SwapQuoterV2.PoolType poolType, address pool);

    /// @notice Emitted when a pool is removed from SwapQuoterV2.
    event PoolRemoved(address bridgeToken, SwapQuoterV2.PoolType poolType, address pool);

    /// @notice Emitted when the SynapseRouter contract is updated.
    event SynapseRouterUpdated(address synapseRouter);

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

    function testSetSynapseRouterEmitsEvent() public {
        address newSynapseRouter = makeAddr("NewSynapseRouter");
        vm.expectEmit();
        emit SynapseRouterUpdated(newSynapseRouter);
        vm.prank(owner);
        quoter.setSynapseRouter(newSynapseRouter);
    }

    function testSetSynapseRouterRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        quoter.setSynapseRouter(address(1));
    }

    // ═════════════════════════════════════════════ TESTS: ADD POOLS ══════════════════════════════════════════════════

    function testAddPoolsEmitsEvents() public {
        SwapQuoterV2.BridgePool[] memory pools = toArray(
            getBridgeDefaultPool(),
            getOriginLinkedPool(),
            getBridgeLinkedPool(),
            getOriginDefaultPool()
        );
        vm.expectEmit();
        emit PoolAdded(neth, SwapQuoterV2.PoolType.Default, poolNethWeth);
        vm.expectEmit();
        emit PoolAdded(address(0), SwapQuoterV2.PoolType.Linked, linkedPoolUsdc);
        vm.expectEmit();
        emit PoolAdded(nusd, SwapQuoterV2.PoolType.Linked, linkedPoolNusd);
        vm.expectEmit();
        emit PoolAdded(address(0), SwapQuoterV2.PoolType.Default, poolUsdcEUsdt);
        vm.recordLogs();
        vm.prank(owner);
        quoter.addPools(pools);
        // Should be exactly 4 events
        assertEq(vm.getRecordedLogs().length, 4);
    }

    function testAddPoolsAddsOriginDefaultPools() public {
        addL2Pools();
        // Should return origin-only Default Pools
        address[] memory defaultPools = quoter.getOriginDefaultPools();
        assertEq(defaultPools.length, 1);
        assertEq(defaultPools[0], poolUsdcEUsdt);
    }

    function testAddPoolsAddsOriginLinkedPools() public {
        addL2Pools();
        // Should return origin-only Linked Pools
        address[] memory linkedPools = quoter.getOriginLinkedPools();
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

    function testAddPoolsEmitsEventWhenReplaces() public {
        addL2Pools();
        // Replace nUSD Linked Pool with Default Pool
        vm.expectEmit();
        emit PoolAdded(nusd, SwapQuoterV2.PoolType.Default, poolNusdUsdcEUsdt);
        vm.recordLogs();
        replaceBridgePool();
        // Should be exactly 1 event
        assertEq(vm.getRecordedLogs().length, 1);
    }

    // ════════════════════════════════════════════ TESTS: REMOVE POOLS ════════════════════════════════════════════════

    function testRemovePoolsEmitsEvents() public {
        addL2Pools();
        SwapQuoterV2.BridgePool[] memory pools = toArray(
            getOriginLinkedPool(),
            getBridgeDefaultPool(),
            getOriginDefaultPool(),
            getBridgeLinkedPool()
        );
        vm.expectEmit();
        emit PoolRemoved(address(0), SwapQuoterV2.PoolType.Linked, linkedPoolUsdc);
        vm.expectEmit();
        emit PoolRemoved(neth, SwapQuoterV2.PoolType.Default, poolNethWeth);
        vm.expectEmit();
        emit PoolRemoved(address(0), SwapQuoterV2.PoolType.Default, poolUsdcEUsdt);
        vm.expectEmit();
        emit PoolRemoved(nusd, SwapQuoterV2.PoolType.Linked, linkedPoolNusd);
        vm.recordLogs();
        vm.prank(owner);
        quoter.removePools(pools);
        // Should be exactly 4 events
        assertEq(vm.getRecordedLogs().length, 4);
    }

    function testRemovePoolsRemovesOriginDefaultPools() public {
        addL2Pools();
        // Remove origin-only Default Pools
        vm.prank(owner);
        quoter.removePools(toArray(getOriginDefaultPool()));
        // Should return no origin-only Default Pools
        address[] memory defaultPools = quoter.getOriginDefaultPools();
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
        address[] memory linkedPools = quoter.getOriginLinkedPools();
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
}
