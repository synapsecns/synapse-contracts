// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockERC20, LinkedPoolTest} from "./LinkedPool.t.sol";

import {MockPoolModule} from "../mocks/MockPoolModule.sol";

// solhint-disable func-name-mixedcase
contract LinkedPoolModuleTest is LinkedPoolTest {
    function setUp() public virtual override {
        poolModule = address(new MockPoolModule());
        super.setUp();
    }

    function test_swap_revert_poolPaused() public override {
        complexSetup();
        // Pause poolB01
        poolB01.setPaused(true);
        uint8 tokenFrom = 3;
        uint8 tokenTo = 7;
        uint256 amount = 100;
        // This goes through the paused pool
        address tokenIn = swap.getToken(tokenFrom);
        uint256 amountIn = amount * (10**MockERC20(tokenIn).decimals());
        prepareUser(tokenIn, amountIn);
        // Expect revert message for failed swap delegated to a pool module
        vm.expectRevert("Swap failed");
        vm.prank(user);
        swap.swap(tokenFrom, tokenTo, amountIn, 0, type(uint256).max);
    }
}
