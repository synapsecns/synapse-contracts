// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {UniversalSwapSetup} from "./UniversalSwapSetup.t.sol";
import {SwapQuoterTest} from "../SwapQuoter.t.sol";

contract SwapQuoterWithUniversalSwapTest is UniversalSwapSetup, SwapQuoterTest {
    function setUp() public override {
        super.setUp();
        deployUniversalSwap(address(neth), address(nEthPool), 2);
        deployUniversalSwap(address(nusd), address(nUsdPool), 4);
    }

    function addPool(
        address bridgeToken,
        address // pool
    ) public override {
        addUniversalSwap(quoter, bridgeToken);
    }

    function removePool(
        address bridgeToken,
        address // pool
    ) public override {
        removeUniversalSwap(quoter, bridgeToken);
    }

    function beforeOwnerOperation() public override {
        vm.prank(OWNER);
    }

    function addedEthPool() public view override returns (address) {
        return tokenToUniversalSwap[address(neth)];
    }

    function addedUsdPool() public view override returns (address) {
        return tokenToUniversalSwap[address(nusd)];
    }
}
