// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSwapQuoterV2Test} from "../quoter/BasicSwapQuoterV2.t.sol";
import {SynapseRouterV2} from "../../../contracts/router/SynapseRouterV2.sol";

// solhint-disable max-states-count
abstract contract BasicSynapseRouterV2Test is BasicSwapQuoterV2Test {
    SynapseRouterV2 public router;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        router = new SynapseRouterV2();
        synapseRouter = address(router);

        vm.prank(owner);
        quoter.setSynapseRouter(address(router));

        vm.prank(owner);
        router.setSwapQuoter(quoter);
    }
}
