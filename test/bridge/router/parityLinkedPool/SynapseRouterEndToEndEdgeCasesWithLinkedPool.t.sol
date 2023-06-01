// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SynapseRouterEndToEndEdgeCasesTest} from "../SynapseRouterEndToEndEdgeCases.t.sol";

contract SynapseRouterEndToEndEdgeCasesWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterEndToEndEdgeCasesTest {
    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployLinkedPool(bridgeToken, pool, tokensAmount);
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
