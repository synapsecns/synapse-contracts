// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";
import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {PoolUtils08} from "../../utils/PoolUtils08.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {console2} from "forge-std/Test.sol";

contract SwapQuoterV2Test is PoolUtils08 {
    using SafeERC20 for IERC20;

    SwapQuoterV2 public quoter;
    address public defaultPoolCalc;
    address public synapseRouter;
    address public weth;
    address public owner;

    function setUp() public virtual override {
        super.setUp();

        synapseRouter = makeAddr("SynapseRouter");
        weth = makeAddr("WETH");
        owner = makeAddr("Owner");

        defaultPoolCalc = address(new DefaultPoolCalc());
        quoter = new SwapQuoterV2({
            synapseRouter_: synapseRouter,
            defaultPoolCalc_: defaultPoolCalc,
            weth_: weth,
            owner_: owner
        });
    }

    function testSetup() public {
        assertEq(quoter.synapseRouter(), synapseRouter);
        assertEq(quoter.defaultPoolCalc(), defaultPoolCalc);
        assertEq(quoter.weth(), weth);
        assertEq(quoter.owner(), owner);
    }

    function testSetSynapseRouterUpdatesSynapseRouter() public {
        address newSynapseRouter = makeAddr("NewSynapseRouter");
        vm.prank(owner);
        quoter.setSynapseRouter(newSynapseRouter);
        assertEq(quoter.synapseRouter(), newSynapseRouter);
    }

    function testSetSynapseRouterRevertsWhenCallerNotOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        quoter.setSynapseRouter(address(1));
    }
}
