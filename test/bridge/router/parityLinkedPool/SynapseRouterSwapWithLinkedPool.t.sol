// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SwapQuoter, SynapseRouterSwapTest} from "../SynapseRouterSwap.t.sol";

contract SynapseRouterSwapWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterSwapTest {
    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool
    ) public override {
        deployLinkedPool(bridgeToken, pool);
        addLinkedPool(swapQuoter, bridgeToken);
    }
}
