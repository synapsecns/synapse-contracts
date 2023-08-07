// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {QuoterV2WithLinkedPoolSetup} from "./QuoterV2WithLinkedPoolSetup.t.sol";
import {SynapseRouterViewsTest, SwapQuoter} from "../SynapseRouterViews.t.sol";

contract SynapseRouterSwapWithBothTest is QuoterV2WithLinkedPoolSetup, SynapseRouterViewsTest {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(QuoterV2WithLinkedPoolSetup, SynapseRouterViewsTest) returns (address quoter_) {
        return QuoterV2WithLinkedPoolSetup.deploySwapQuoter(router_, weth_, owner);
    }

    function addSwapPool(
        SwapQuoter swapQuoter,
        address bridgeToken,
        address pool
    ) public virtual override {
        deployLinkedPool(bridgeToken, pool);
        addBridgeLinkedPool(address(swapQuoter), bridgeToken);
    }

    function addNexusPool() public virtual override {
        addBridgeDefaultPool(address(quoter), address(nexusNusd), address(nexusPool));
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
