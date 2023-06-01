// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SwapQuoter, SynapseRouterViewsTest} from "../SynapseRouterViews.t.sol";

contract SynapseRouterViewsWithLinkedPoolTest is LinkedPoolSetup, SynapseRouterViewsTest {
    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public override {
        deployLinkedPool(bridgeToken, pool, tokensAmount);
        addLinkedPool(swapQuoter, bridgeToken);
    }

    function addedEthPool() public view override returns (address) {
        return tokenToLinkedPool[address(neth)];
    }

    function addedUsdPool() public view override returns (address) {
        return tokenToLinkedPool[address(nusd)];
    }

    function _getLpToken(address pool) internal view override returns (address) {
        if (pool == nexusPool) return address(nexusNusd);
        // Instead of other pools we add LinkedPool pools which don't have LP tokens
        return address(0);
    }
}
