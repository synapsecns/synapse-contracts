// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SwapQuoter, SynapseRouterSwapTest} from "../SynapseRouterSwap.t.sol";
import {SwapQuoterV2Setup} from "./SwapQuoterV2Setup.t.sol";

contract SynapseRouterSwapWithQuoterV2Test is SwapQuoterV2Setup, SynapseRouterSwapTest {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(SwapQuoterV2Setup, SynapseRouterSwapTest) returns (address quoter_) {
        return SwapQuoterV2Setup.deploySwapQuoter(router_, weth_, owner);
    }

    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool
    ) public virtual override {
        addBridgeDefaultPool(address(swapQuoter), bridgeToken, pool);
    }

    // Tests from the parent class are inherited, and they will be using SwapQuoterV2 instead of SwapQuoter
}
