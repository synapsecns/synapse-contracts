// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SynapseRouterEndToEndNUSDTest} from "../SynapseRouterEndToEndNUSD.t.sol";

contract SynapseRouterEndToEndNUSDWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterEndToEndNUSDTest {
    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployLinkedPool(bridgeToken, pool, tokensAmount);
        addLinkedPool(chain.quoter, bridgeToken);
    }
}
