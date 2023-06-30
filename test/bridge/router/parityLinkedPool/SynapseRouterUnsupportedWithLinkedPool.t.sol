// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SwapQuoter, SynapseRouterUnsupportedTest} from "../SynapseRouterUnsupported.t.sol";

contract SynapseRouterUnsupportedWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterUnsupportedTest {
    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool
    ) public override {
        deployLinkedPool(bridgeToken, pool);
        addLinkedPool(swapQuoter, bridgeToken);
    }
}
