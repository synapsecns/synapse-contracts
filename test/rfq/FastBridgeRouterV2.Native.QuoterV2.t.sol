// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouterV2NativeTest} from "./FastBridgeRouterV2.Native.t.sol";
import {DefaultPoolCalc} from "../../contracts/router/quoter/DefaultPoolCalc.sol";
import {SwapQuoterV2} from "../../contracts/router/quoter/SwapQuoterV2.sol";

contract FastBridgeRouterV2NativeQuoterV2Test is FastBridgeRouterV2NativeTest {
    function setUpSwapQuoter() internal override {
        DefaultPoolCalc poolCalc = new DefaultPoolCalc();
        SwapQuoterV2 quoter = new SwapQuoterV2({
            // Existing SwapQuoter will be always pointing towards another router
            synapseRouter_: address(1),
            defaultPoolCalc_: address(poolCalc),
            weth_: address(weth),
            owner_: address(this)
        });
        addPool(quoter);
        vm.prank(owner);
        router.setSwapQuoter(address(quoter));
    }

    function addPool(SwapQuoterV2 quoter) internal {
        SwapQuoterV2.BridgePool[] memory pools = new SwapQuoterV2.BridgePool[](1);
        pools[0] = SwapQuoterV2.BridgePool({
            bridgeToken: address(0),
            poolType: SwapQuoterV2.PoolType.Default,
            pool: address(pool)
        });
        quoter.addPools(pools);
    }
}
