// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {IDssPsm} from "../../../interfaces/dss/IDssPsm.sol";
import {IDssGemJoin} from "../../../interfaces/dss/IDssGemJoin.sol";

import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

/// @notice PoolModule for MakerDAO Dai PSM modules
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract DssPsmModule is OnlyDelegateCall, IPoolModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        assertDelegateCall();
        address dai = IDssPsm(pool).dai();
        amountOut = getPoolQuote(pool, tokenFrom, tokenTo, amountIn, false);
        IERC20(tokenFrom.token).safeApprove(pool, amountIn);

        // in case of transfer fees
        uint256 balanceTo = IERC20(tokenTo.token).balanceOf(address(this));
        if (tokenFrom.token == dai) {
            IDssPsm(pool).buyGem(address(this), amountOut);
        } else {
            IDssPsm(pool).sellGem(address(this), amountIn);
        }
        amountOut = IERC20(tokenTo.token).balanceOf(address(this)) - balanceTo;
    }

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) public view returns (uint256 amountOut) {
        // TODO: check one token is dai and the other token is the gem
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {
        address dai = IDssPsm(pool).dai();
        address gemJoin = IDssPsm(pool).gemJoin();
        address gem = IDssGemJoin(gemJoin).gem();

        tokens = new address[](2);
        tokens[0] = dai;
        tokens[1] = gem;
    }
}
