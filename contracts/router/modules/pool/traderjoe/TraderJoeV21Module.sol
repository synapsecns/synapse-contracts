// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILBRouter} from "../../../interfaces/traderjoe/ILBRouter.sol";
import {ILBPair} from "../../../interfaces/traderjoe/ILBPair.sol";
import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";

import {TraderJoeModule} from "./TraderJoeModule.sol";

contract TraderJoeV21Module is TraderJoeModule {
    constructor(address _lbRouter) TraderJoeModule(_lbRouter) {}

    function version() public view override returns (ILBRouter.Version) {
        return ILBRouter.Version.V2_1;
    }

    function _binStep(address pool) internal view override returns (uint256) {
        return ILBPair(pool).getBinStep();
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) public view override returns (uint256 amountOut) {
        address[] memory tokens = getPoolTokens(pool);
        bool swapForY = (tokenTo.token == tokens[1]);
        require(amountIn <= type(uint128).max, "amountIn > type(uint128).max");
        (, amountOut, ) = lbRouter.getSwapOut(ILBPair(pool), uint128(amountIn), swapForY);
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) public view override returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = address(ILBPair(pool).getTokenX());
        tokens[1] = address(ILBPair(pool).getTokenY());
    }
}
