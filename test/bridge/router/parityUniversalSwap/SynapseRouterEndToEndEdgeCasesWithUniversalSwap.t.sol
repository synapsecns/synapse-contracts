// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {UniversalSwapSetup} from "./UniversalSwapSetup.t.sol";
import {SynapseRouterEndToEndEdgeCasesTest} from "../SynapseRouterEndToEndEdgeCases.t.sol";

contract SynapseRouterEndToEndEdgeCasesWithUniversalSwapTest is UniversalSwapSetup, SynapseRouterEndToEndEdgeCasesTest {
    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployUniversalSwap(bridgeToken, pool, tokensAmount);
        addUniversalSwap(chain.quoter, bridgeToken);
    }

    function removeSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address // pool
    ) public override {
        removeUniversalSwap(chain.quoter, bridgeToken);
    }
}
