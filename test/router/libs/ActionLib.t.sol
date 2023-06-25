// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, ActionLibHarness} from "../harnesses/ActionLibHarness.sol";

import {Test} from "forge-std/Test.sol";

contract ActionLibraryTest is Test {
    ActionLibHarness public libHarness;

    uint256 public constant MAX_ACTION = uint8(type(Action).max) + 1;

    function setUp() public {
        libHarness = new ActionLibHarness();
    }

    function testAllActions() public {
        uint256 allActions = libHarness.allActions();
        for (uint8 i = 0; i < MAX_ACTION; i++) {
            assertTrue(libHarness.isIncluded(Action(i), allActions));
        }
    }

    function testIsIncluded(
        bool swap,
        bool addLiquidity,
        bool removeLiquidity,
        bool handleEth
    ) public {
        uint256 mask = 0;
        if (swap) mask += 2**0;
        if (addLiquidity) mask += 2**1;
        if (removeLiquidity) mask += 2**2;
        if (handleEth) mask += 2**3;
        assertEq(libHarness.isIncluded(Action.Swap, mask), swap);
        assertEq(libHarness.isIncluded(Action.AddLiquidity, mask), addLiquidity);
        assertEq(libHarness.isIncluded(Action.RemoveLiquidity, mask), removeLiquidity);
        assertEq(libHarness.isIncluded(Action.HandleEth, mask), handleEth);
    }

    function testMaskOneAction() public {
        assertEq(libHarness.mask(Action.Swap), 2**0);
        assertEq(libHarness.mask(Action.AddLiquidity), 2**1);
        assertEq(libHarness.mask(Action.RemoveLiquidity), 2**2);
        assertEq(libHarness.mask(Action.HandleEth), 2**3);
    }

    function testMaskTwoDifferentActions() public {
        assertEq(libHarness.mask(Action.Swap, Action.AddLiquidity), 2**0 + 2**1);
        assertEq(libHarness.mask(Action.Swap, Action.RemoveLiquidity), 2**0 + 2**2);
        assertEq(libHarness.mask(Action.Swap, Action.HandleEth), 2**0 + 2**3);

        assertEq(libHarness.mask(Action.AddLiquidity, Action.Swap), 2**1 + 2**0);
        assertEq(libHarness.mask(Action.AddLiquidity, Action.RemoveLiquidity), 2**1 + 2**2);
        assertEq(libHarness.mask(Action.AddLiquidity, Action.HandleEth), 2**1 + 2**3);

        assertEq(libHarness.mask(Action.RemoveLiquidity, Action.Swap), 2**2 + 2**0);
        assertEq(libHarness.mask(Action.RemoveLiquidity, Action.AddLiquidity), 2**2 + 2**1);
        assertEq(libHarness.mask(Action.RemoveLiquidity, Action.HandleEth), 2**2 + 2**3);

        assertEq(libHarness.mask(Action.HandleEth, Action.Swap), 2**3 + 2**0);
        assertEq(libHarness.mask(Action.HandleEth, Action.AddLiquidity), 2**3 + 2**1);
        assertEq(libHarness.mask(Action.HandleEth, Action.RemoveLiquidity), 2**3 + 2**2);
    }

    function testMaskTwoSameActions() public {
        assertEq(libHarness.mask(Action.Swap, Action.Swap), 2**0);
        assertEq(libHarness.mask(Action.AddLiquidity, Action.AddLiquidity), 2**1);
        assertEq(libHarness.mask(Action.RemoveLiquidity, Action.RemoveLiquidity), 2**2);
        assertEq(libHarness.mask(Action.HandleEth, Action.HandleEth), 2**3);
    }
}
