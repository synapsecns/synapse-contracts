// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SynapseRouterSuite, SynapseRouterEndToEndJewelTest} from "../SynapseRouterEndToEndJewel.t.sol";
import {SwapQuoterV2Setup} from "./SwapQuoterV2Setup.t.sol";

contract SynapseRouterEndToEndJewelWithQuoterV2Test is SwapQuoterV2Setup, SynapseRouterEndToEndJewelTest {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(SwapQuoterV2Setup, SynapseRouterSuite) returns (address quoter_) {
        return SwapQuoterV2Setup.deploySwapQuoter(router_, weth_, owner);
    }

    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public virtual override {
        addBridgeDefaultPool(address(chain.quoter), bridgeToken, pool);
    }

    function addDefaultPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public virtual override {
        addBridgeDefaultPool(address(chain.quoter), bridgeToken, pool);
    }

    function removeSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public virtual override {
        removeBridgeDefaultPool(address(chain.quoter), bridgeToken, pool);
    }

    // Tests from the parent class are inherited, and they will be using SwapQuoterV2 instead of SwapQuoter
}
