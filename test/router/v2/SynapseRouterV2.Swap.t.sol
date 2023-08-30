// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockERC20} from "../mocks/MockERC20.sol";
import {Action, ActionLib, BridgeToken, DefaultParams, LimitedToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";
import {QueryEmpty} from "../../../contracts/router/libs/Errors.sol";

import {BasicSynapseRouterV2Test} from "./BasicSynapseRouterV2.t.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterV2SwapTest is BasicSynapseRouterV2Test {
    function testSwap() public {
        addL2Pools(); // L2 swap

        address to = address(0xA);
        address token = weth;
        uint256 amount = 1e18;

        prepareUser(token, amount);
        uint256 balancePool = MockERC20(token).balanceOf(poolNethWeth);

        // origin adapter should swap weth for neth
        address tokenOut = neth;
        uint256 amountOut = quoter
            .getAmountOut(LimitedToken({token: weth, actionMask: ActionLib.allActions()}), tokenOut, amount)
            .minAmountOut;
        SwapQuery memory query = SwapQuery({
            routerAdapter: address(router), // "router" on origin chain
            tokenOut: neth,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: getSwapParams(address(poolNethWeth), 1, 0)
        });

        vm.prank(user);
        assertEq(router.swap(to, token, amount, query), amountOut);

        // test token pulled and transferred to pool with tokenOut sent to recipient
        assertEq(MockERC20(token).balanceOf(poolNethWeth), balancePool + amount);
        assertEq(MockERC20(tokenOut).balanceOf(to), amountOut);
    }

    function testSwap_revert_queryEmpty() public {
        addL2Pools(); // L2 swap

        address to = address(0xA);
        address token = weth;
        uint256 amount = 1e18;

        prepareUser(token, amount);

        // empty query
        SwapQuery memory query;

        vm.expectRevert(QueryEmpty.selector);
        vm.prank(user);
        router.swap(to, token, amount, query);
    }
}
