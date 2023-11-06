// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultPoolCalc} from "../../../interfaces/IDefaultPoolCalc.sol";
import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";

import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

/// @notice PoolModule for the Nexus pool. Treats the pool's LP token (nUSD) as an additional pool token.
/// poolToken -> lpToken is done by providing liquidity in a form of a single token.
/// lpToken -> poolToken is done by removing liquidity in a form of a single token.
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract NexusPoolModule is OnlyDelegateCall, IPoolModule {
    IDefaultPoolCalc public immutable defaultPoolCalc;

    constructor(address defaultPoolCalc_) {
        defaultPoolCalc = IDefaultPoolCalc(defaultPoolCalc_);
    }

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // This function should be only called via delegatecall
        assertDelegateCall();
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IPoolModule
    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut) {}

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view returns (address[] memory tokens) {}
}
