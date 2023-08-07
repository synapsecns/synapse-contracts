// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SwapQuoterTest} from "../SwapQuoter.t.sol";
import {ISwapQuoterV2, SwapQuoterV2Setup} from "./SwapQuoterV2Setup.t.sol";

// solhint-disable func-name-mixedcase
contract SwapQuoterWithQuoterV2Test is SwapQuoterV2Setup, SwapQuoterTest {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal override(SwapQuoterV2Setup, SwapQuoterTest) returns (address quoter_) {
        return SwapQuoterV2Setup.deploySwapQuoter(router_, weth_, owner);
    }

    function addPool(address bridgeToken, address pool) public virtual override {
        addBridgeDefaultPool(address(quoter), bridgeToken, pool);
    }

    function removePool(address bridgeToken, address pool) public virtual override {
        removeBridgeDefaultPool(address(quoter), bridgeToken, pool);
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
        ISwapQuoterV2 swapQuoterV2 = ISwapQuoterV2(address(quoter));
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        swapQuoterV2.addPools(new ISwapQuoterV2.BridgePool[](0));
    }

    function test_removePool_revert_onlyOwner(address caller) public virtual override {
        // No-op as `.removePool()` is not supported on SwapQuoterV2
    }

    function test_removePools_revert_onlyOwner(address caller) public {
        ISwapQuoterV2 swapQuoterV2 = ISwapQuoterV2(address(quoter));
        vm.assume(caller != OWNER);
        expectOnlyOwnerRevert();
        vm.prank(caller);
        swapQuoterV2.removePools(new ISwapQuoterV2.BridgePool[](0));
    }

    function test_getAmountOut_swap(uint256 actionMask) public virtual override {
        // TODO: this should be covered in the new SwapQuoterV2 tests
    }
}
