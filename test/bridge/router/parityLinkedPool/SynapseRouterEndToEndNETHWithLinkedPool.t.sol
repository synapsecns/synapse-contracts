// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SynapseRouterEndToEndNETHTest} from "../SynapseRouterEndToEndNETH.t.sol";

contract SynapseRouterEndToEndNETHWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterEndToEndNETHTest {
    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public override {
        deployLinkedPool(bridgeToken, pool);
        addLinkedPool(chain.quoter, bridgeToken);
    }
}
