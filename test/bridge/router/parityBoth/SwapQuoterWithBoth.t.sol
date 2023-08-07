// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {QuoterV2WithLinkedPoolSetup} from "./QuoterV2WithLinkedPoolSetup.t.sol";
import {SwapQuoterTest} from "../SwapQuoter.t.sol";

contract SwapQuoterWithBothTest is QuoterV2WithLinkedPoolSetup, SwapQuoterTest {
    function setUp() public override {
        super.setUp();
        deployLinkedPool(address(neth), address(nEthPool));
        deployLinkedPool(address(nusd), address(nUsdPool));
    }

    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(QuoterV2WithLinkedPoolSetup, SwapQuoterTest) returns (address quoter_) {
        return QuoterV2WithLinkedPoolSetup.deploySwapQuoter(router_, weth_, owner);
    }

    function addPool(address bridgeToken, address) public virtual override {
        addBridgeLinkedPool(address(quoter), bridgeToken);
    }

    function removePool(address bridgeToken, address) public virtual override {
        removeBridgeLinkedPool(address(quoter), bridgeToken);
    }

    function addedEthPool() public view override returns (address) {
        return tokenToLinkedPool[address(neth)];
    }

    function addedUsdPool() public view override returns (address) {
        return tokenToLinkedPool[address(nusd)];
    }

    function beforeOwnerOperation() public virtual override {
        vm.prank(OWNER);
    }

    // Tests from the parent class are inherited, and they will be using SwapQuoterV2 instead of SwapQuoter

    function test_addPools() public virtual override {
        // No need to differentiate between `addPools` and `addPool` in QuoterV2
        test_addPool();
    }

    function test_addPool_revert_onlyOwner(address caller) public virtual override {
        // No-op as `.addPool()` is not supported on SwapQuoterV2
    }

    function test_addPools_revert_onlyOwner(address caller) public virtual override {
        // No-op as this is covered in the new SwapQuoterV2 tests
    }

    function test_removePool_revert_onlyOwner(address caller) public virtual override {
        // No-op as `.removePool()` is not supported on SwapQuoterV2
    }

    function test_removePools_revert_onlyOwner(address caller) public {
        // No-op as this is covered in the new SwapQuoterV2 tests
    }

    function test_getAmountOut_swap(uint256 actionMask) public virtual override {
        // TODO: this should be covered in the new SwapQuoterV2 tests
    }
}
