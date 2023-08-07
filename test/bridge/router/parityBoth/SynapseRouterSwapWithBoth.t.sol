// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {QuoterV2WithLinkedPoolSetup} from "./QuoterV2WithLinkedPoolSetup.t.sol";
import {SynapseRouterSwapTest, SwapQuoter} from "../SynapseRouterSwap.t.sol";

contract SynapseRouterSwapWithBothTest is QuoterV2WithLinkedPoolSetup, SynapseRouterSwapTest {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(QuoterV2WithLinkedPoolSetup, SynapseRouterSwapTest) returns (address quoter_) {
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
}
