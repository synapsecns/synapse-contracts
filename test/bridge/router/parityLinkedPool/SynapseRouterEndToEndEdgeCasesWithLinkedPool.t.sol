// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SynapseRouterEndToEndEdgeCasesTest} from "../SynapseRouterEndToEndEdgeCases.t.sol";

contract SynapseRouterEndToEndEdgeCasesWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterEndToEndEdgeCasesTest {
    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public override {
        deployLinkedPool(bridgeToken, pool);
        addLinkedPool(chain.quoter, bridgeToken);
    }

    function removeSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address // pool
    ) public override {
        removeLinkedPool(chain.quoter, bridgeToken);
    }
}
