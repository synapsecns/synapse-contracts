// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {UniversalSwapSetup} from "./UniversalSwapSetup.t.sol";
import {SwapQuoter, SynapseRouterSwapTest} from "../SynapseRouterSwap.t.sol";

contract SynapseRouterSwapWithUniversalSwapTest is UniversalSwapSetup, SynapseRouterSwapTest {
    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployUniversalSwap(bridgeToken, pool, tokensAmount);
        addUniversalSwap(swapQuoter, bridgeToken);
    }
}
