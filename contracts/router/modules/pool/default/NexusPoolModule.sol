// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../interfaces/IDefaultExtendedPool.sol";
import {IDefaultPoolCalc} from "../../../interfaces/IDefaultPoolCalc.sol";
import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";

import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

/// @notice PoolModule for the Nexus pool. Treats the pool's LP token (nUSD) as an additional pool token.
/// poolToken -> lpToken is done by providing liquidity in a form of a single token.
/// lpToken -> poolToken is done by removing liquidity in a form of a single token.
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract NexusPoolModule is OnlyDelegateCall, IPoolModule {
    IDefaultPoolCalc public immutable defaultPoolCalc;
    /// These need to be immutable in order to be accessed via delegatecall
    address public immutable nexusPool;
    uint256 public immutable nexusPoolNumTokens;
    address public immutable nexusPoolLpToken;

    constructor(address defaultPoolCalc_, address nexusPool_) {
        defaultPoolCalc = IDefaultPoolCalc(defaultPoolCalc_);
        // Save all the pool information during the deployment
        nexusPool = nexusPool_;
        nexusPoolNumTokens = _numTokens(nexusPool_);
        nexusPoolLpToken = _lpToken(nexusPool_);
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

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Returns the LP token address for the given pool.
    function _lpToken(address pool) internal view returns (address lpToken) {
        (, , , , , , lpToken) = IDefaultExtendedPool(pool).swapStorage();
    }

    /// @dev Returns the number of tokens in the pool, excluding the LP token.
    function _numTokens(address pool) internal view returns (uint256 numTokens) {
        /// @dev same logic as LinkedPool.sol::_getPoolTokens
        while (true) {
            try IDefaultExtendedPool(pool).getToken(uint8(numTokens)) returns (address) {
                unchecked {
                    ++numTokens;
                }
            } catch {
                break;
            }
        }
    }
}
