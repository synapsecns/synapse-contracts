// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts-4.8.0/utils/math/Math.sol";

import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";
import {IDssPsm} from "../../../interfaces/dss/IDssPsm.sol";
import {IDssGemJoin} from "../../../interfaces/dss/IDssGemJoin.sol";
import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";

import {OnlyDelegateCall} from "../OnlyDelegateCall.sol";

/// @notice PoolModule for MakerDAO Dai PSM modules
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract DssPsmModule is OnlyDelegateCall, IPoolModule {
    using UniversalTokenLib for address;

    uint256 private constant wad = 1e18;

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        assertDelegateCall();
        amountOut = getPoolQuote(pool, tokenFrom, tokenTo, amountIn, false);

        // in case of transfer fees
        uint256 balanceTo = IERC20(tokenTo.token).balanceOf(address(this));
        if (tokenFrom.index == 0) {
            tokenFrom.token.universalApproveInfinity(pool, amountIn);
            IDssPsm(pool).buyGem(address(this), amountOut);
        } else {
            address gemJoin = IDssPsm(pool).gemJoin();
            tokenFrom.token.universalApproveInfinity(gemJoin, amountIn);
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
        address[] memory tokens = getPoolTokens(pool);
        address dai = tokens[0];
        address gem = tokens[1];
        require(
            (tokenFrom.token == dai && tokenTo.token == gem) || (tokenFrom.token == gem && tokenTo.token == dai),
            "tokens not in pool"
        );

        IndexedToken memory tokenDai = tokenFrom.token == dai ? tokenFrom : tokenTo;
        IndexedToken memory tokenGem = tokenTo.token == gem ? tokenTo : tokenFrom;
        require(tokenDai.index == 0 && tokenGem.index == 1, "token indices not valid");

        uint256 gemDec = IDssGemJoin(IDssPsm(pool).gemJoin()).dec();
        if (tokenFrom.token == dai) {
            uint256 tout = IDssPsm(pool).tout();
            uint256 amountOutWad = Math.mulDiv(amountIn, wad, wad + tout);
            amountOut = Math.mulDiv(amountOutWad, 10**gemDec, wad);
        } else {
            uint256 amountInWad = Math.mulDiv(amountIn, wad, 10**gemDec);
            uint256 tin = IDssPsm(pool).tin();
            amountOut = Math.mulDiv(amountInWad, wad - tin, wad);
        }
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) public view returns (address[] memory tokens) {
        address dai = IDssPsm(pool).dai();
        address gemJoin = IDssPsm(pool).gemJoin();
        address gem = IDssGemJoin(gemJoin).gem();

        tokens = new address[](2);
        tokens[0] = dai;
        tokens[1] = gem;
    }
}
