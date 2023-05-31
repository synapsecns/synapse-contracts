// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {UniversalSwapSetup} from "./UniversalSwapSetup.t.sol";
import {SwapQuoter, SynapseRouterViewsTest} from "../SynapseRouterViews.t.sol";

contract SynapseRouterViewsWithUniversalSwapTest is UniversalSwapSetup, SynapseRouterViewsTest {
    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployUniversalSwap(bridgeToken, pool, tokensAmount);
        addUniversalSwap(swapQuoter, bridgeToken);
    }

    function addedEthPool() public view override returns (address) {
        return tokenToUniversalSwap[address(neth)];
    }

    function addedUsdPool() public view override returns (address) {
        return tokenToUniversalSwap[address(nusd)];
    }

    function _getLpToken(address pool) internal view override returns (address) {
        if (pool == nexusPool) return address(nexusNusd);
        // Instead of other pools we add UniversalSwap pools which don't have LP tokens
        return address(0);
    }
}
