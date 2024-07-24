// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouterV2} from "../../contracts/rfq/FastBridgeRouterV2.sol";

import {FastBridgeRouterTest, SwapQuery} from "./FastBridgeRouter.t.sol";

abstract contract FastBridgeRouterV2Test is FastBridgeRouterTest {
    function deployRouter() public virtual override returns (address payable) {
        return payable(new FastBridgeRouterV2(owner));
    }

    function getDestQueryNoRebateWithOriginSender(uint256 amount, address originSender)
        public
        view
        returns (SwapQuery memory destQuery)
    {
        destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amount - FIXED_FEE,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: abi.encodePacked(uint8(0), originSender)
        });
    }

    function getDestQueryWithRebateWithOriginSender(uint256 amount, address originSender)
        public
        view
        returns (SwapQuery memory destQuery)
    {
        destQuery = SwapQuery({
            routerAdapter: address(0),
            tokenOut: TOKEN_OUT,
            minAmountOut: amount - FIXED_FEE,
            deadline: block.timestamp + RFQ_DEADLINE,
            rawParams: abi.encodePacked(REBATE_FLAG, originSender)
        });
    }

    function expectRevertOriginSenderNotSpecified() public {
        vm.expectRevert(FastBridgeRouterV2.FastBridgeRouterV2__OriginSenderNotSpecified.selector);
    }
}
