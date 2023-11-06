// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../interfaces/IDefaultExtendedPool.sol";
import {IDefaultPoolCalc} from "../../../interfaces/IDefaultPoolCalc.sol";
import {IPausable} from "../../../interfaces/IPausable.sol";
import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";

import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

/// @notice PoolModule for the Nexus pool. Treats the pool's LP token (nUSD) as an additional pool token.
/// poolToken -> lpToken is done by providing liquidity in a form of a single token.
/// lpToken -> poolToken is done by removing liquidity in a form of a single token.
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract NexusPoolModule is OnlyDelegateCall, IPoolModule {
    error NexusPoolModule__EqualIndexes(uint8 tokenIndex);
    error NexusPoolModule__Paused();
    error NexusPoolModule__UnsupportedIndex(uint8 tokenIndex);
    error NexusPoolModule__UnsupportedPool(address pool);

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

    modifier onlyNexusPool(address pool) {
        if (pool != nexusPool) revert NexusPoolModule__UnsupportedPool(pool);
        _;
    }

    modifier onlySupportedIndexes(uint8 tokenIndexFrom, uint8 tokenIndexTo) {
        if (tokenIndexFrom > nexusPoolNumTokens) revert NexusPoolModule__UnsupportedIndex(tokenIndexFrom);
        if (tokenIndexTo > nexusPoolNumTokens) revert NexusPoolModule__UnsupportedIndex(tokenIndexTo);
        if (tokenIndexFrom == tokenIndexTo) revert NexusPoolModule__EqualIndexes(tokenIndexFrom);
        _;
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
    )
        external
        view
        onlyNexusPool(pool)
        onlySupportedIndexes(tokenFrom.index, tokenTo.index)
        returns (uint256 amountOut)
    {
        if (probePaused && IPausable(pool).paused()) revert NexusPoolModule__Paused();
        if (tokenFrom.index == nexusPoolNumTokens) {
            // Case 1: tokenFrom == nUSD -> remove liquidity
            amountOut = IDefaultExtendedPool(pool).calculateRemoveLiquidityOneToken({
                tokenAmount: amountIn,
                tokenIndex: tokenTo.index
            });
        } else if (tokenTo.index == nexusPoolNumTokens) {
            // Case 2: tokenTo == nUSD -> add liquidity
            // Need to use DefaultPoolCalc to get the precise quote
            uint256[] memory amounts = new uint256[](nexusPoolNumTokens);
            amounts[tokenFrom.index] = amountIn;
            amountOut = defaultPoolCalc.calculateAddLiquidity(nexusPool, amounts);
        } else {
            // Case 3: tokenFrom != nUSD && tokenTo != nUSD -> swap
            amountOut = IDefaultExtendedPool(pool).calculateSwap({
                tokenIndexFrom: tokenFrom.index,
                tokenIndexTo: tokenTo.index,
                dx: amountIn
            });
        }
    }

    /// @inheritdoc IPoolModule
    function getPoolTokens(address pool) external view onlyNexusPool(pool) returns (address[] memory tokens) {
        // Extend the list of pool tokens with the LP token
        tokens = new address[](nexusPoolNumTokens + 1);
        for (uint256 i = 0; i < nexusPoolNumTokens; i++) {
            tokens[i] = IDefaultExtendedPool(pool).getToken(uint8(i));
        }
        tokens[nexusPoolNumTokens] = nexusPoolLpToken;
    }

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
