// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouterV2NativeTest} from "./FastBridgeRouterV2.Native.t.sol";
import {ISwapQuoterV1} from "../interfaces/ISwapQuoterV1.sol";

contract FastBridgeRouterV2NativeQuoterV1Test is FastBridgeRouterV2NativeTest {
    function setUpSwapQuoter() internal override {
        // SwapQuoter V1 is solidity 0.6.12, so we use the cheatcode to deploy it
        // new SwapQuoter(synapseRouter, weth, owner)
        bytes memory constructorArgs = abi.encode(
            // Existing SwapQuoter will be always pointing towards another router
            address(1), // synapseRouter
            address(weth), // weth
            address(this) // owner
        );
        address swapQuoter = deployCode("SwapQuoter.sol", constructorArgs);
        addPool(swapQuoter);
        vm.prank(owner);
        router.setSwapQuoter(swapQuoter);
    }

    function addPool(address swapQuoter) internal {
        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        ISwapQuoterV1(swapQuoter).addPools(pools);
    }
}
