// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {QuoterV2WithLinkedPoolSetup} from "./QuoterV2WithLinkedPoolSetup.t.sol";
import {SynapseRouterEndToEndJewelTest, SynapseRouterSuite} from "../SynapseRouterEndToEndJewel.t.sol";

contract SynapseRouterEndToEndJewelWithBothTest is QuoterV2WithLinkedPoolSetup, SynapseRouterEndToEndJewelTest {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(QuoterV2WithLinkedPoolSetup, SynapseRouterSuite) returns (address quoter_) {
        return QuoterV2WithLinkedPoolSetup.deploySwapQuoter(router_, weth_, owner);
    }

    function addSwapPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public virtual override {
        deployLinkedPool(bridgeToken, pool);
        addBridgeLinkedPool(address(chain.quoter), bridgeToken);
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
        address
    ) public virtual override {
        removeBridgeLinkedPool(address(chain.quoter), bridgeToken);
    }

    function removeDefaultPool(
        ChainSetup memory chain,
        address bridgeToken,
        address pool
    ) public virtual override {
        removeBridgeDefaultPool(address(chain.quoter), bridgeToken, pool);
    }
}
