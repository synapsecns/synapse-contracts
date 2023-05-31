// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {UniversalSwapSetup} from "./UniversalSwapSetup.t.sol";
import {SynapseRouterEndToEndNETHTest} from "../SynapseRouterEndToEndNETH.t.sol";

contract SynapseRouterEndToEndNETHWithUniversalSwapTest is UniversalSwapSetup, SynapseRouterEndToEndNETHTest {
    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployUniversalSwap(bridgeToken, pool, tokensAmount);
        addUniversalSwap(chain.quoter, bridgeToken);
    }
}
