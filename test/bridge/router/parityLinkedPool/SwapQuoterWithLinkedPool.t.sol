// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LinkedPoolSetup} from "./LinkedPoolSetup.t.sol";
import {SwapQuoterTest} from "../SwapQuoter.t.sol";

contract SwapQuoterWithLinkedPoolTest is LinkedPoolSetup, SwapQuoterTest {
    function setUp() public override {
        super.setUp();
        deployLinkedPool(address(neth), address(nEthPool), 2);
        deployLinkedPool(address(nusd), address(nUsdPool), 4);
    }

    function addPool(
        address bridgeToken,
        address // pool
    ) public override {
        addLinkedPool(quoter, bridgeToken);
    }

    function removePool(
        address bridgeToken,
        address // pool
    ) public override {
        removeLinkedPool(quoter, bridgeToken);
    }

    function beforeOwnerOperation() public override {
        vm.prank(OWNER);
    }

    function addedEthPool() public view override returns (address) {
        return tokenToLinkedPool[address(neth)];
    }

    function addedUsdPool() public view override returns (address) {
        return tokenToLinkedPool[address(nusd)];
    }
}
