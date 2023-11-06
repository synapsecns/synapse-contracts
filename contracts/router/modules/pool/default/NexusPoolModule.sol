// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IDefaultExtendedPool} from "../../../interfaces/IDefaultExtendedPool.sol";
import {IDefaultPoolCalc} from "../../../interfaces/IDefaultPoolCalc.sol";
import {IPausable} from "../../../interfaces/IPausable.sol";
import {IndexedToken, IPoolModule} from "../../../interfaces/IPoolModule.sol";

import {UniversalTokenLib} from "../../../libs/UniversalToken.sol";

import {OnlyDelegateCall} from "../../OnlyDelegateCall.sol";

/// @notice PoolModule for the Nexus pool. Treats the pool's LP token (nUSD) as an additional pool token.
/// poolToken -> lpToken is done by providing liquidity in a form of a single token.
/// lpToken -> poolToken is done by removing liquidity in a form of a single token.
/// @dev Implements IPoolModule interface to be used with pools added to LinkedPool router
contract NexusPoolModule is OnlyDelegateCall, IPoolModule {
    using UniversalTokenLib for address;

    error NexusPoolModule__EqualIndexes(uint8 tokenIndex);
    error NexusPoolModule__Paused();
    error NexusPoolModule__UnsupportedIndex(uint8 tokenIndex);
    error NexusPoolModule__UnsupportedPool(address pool);

    address public constant DEFAULT_POOL_CALC = 0x0000000000F54b784E70E1Cf1F99FB53b08D6FEA;
    address public constant NEXUS_POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
    uint256 public constant NUM_TOKENS = 3;
    address public constant NUSD = 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F;

    modifier onlyNexusPool(address pool) {
        if (pool != NEXUS_POOL) revert NexusPoolModule__UnsupportedPool(pool);
        _;
    }

    modifier onlySupportedIndexes(uint8 tokenIndexFrom, uint8 tokenIndexTo) {
        if (tokenIndexFrom > NUM_TOKENS) revert NexusPoolModule__UnsupportedIndex(tokenIndexFrom);
        if (tokenIndexTo > NUM_TOKENS) revert NexusPoolModule__UnsupportedIndex(tokenIndexTo);
        if (tokenIndexFrom == tokenIndexTo) revert NexusPoolModule__EqualIndexes(tokenIndexFrom);
        _;
    }

    /// @inheritdoc IPoolModule
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external onlyNexusPool(pool) onlySupportedIndexes(tokenFrom.index, tokenTo.index) returns (uint256 amountOut) {
        // This function should be only called via delegatecall
        assertDelegateCall();
        // Approve tokenIn for spending by the pool no matter what the action is
        tokenFrom.token.universalApproveInfinity({spender: pool, amountToSpend: amountIn});
        if (tokenFrom.index == NUM_TOKENS) {
            // Case 1: tokenFrom == nUSD -> remove liquidity
            amountOut = IDefaultExtendedPool(pool).removeLiquidityOneToken({
                tokenAmount: amountIn,
                tokenIndex: tokenTo.index,
                minAmount: 0,
                deadline: block.timestamp
            });
        } else if (tokenTo.index == NUM_TOKENS) {
            // Case 2: tokenTo == nUSD -> add liquidity
            uint256[] memory amounts = new uint256[](NUM_TOKENS);
            amounts[tokenFrom.index] = amountIn;
            amountOut = IDefaultExtendedPool(pool).addLiquidity({
                amounts: amounts,
                minToMint: 0,
                deadline: block.timestamp
            });
        } else {
            // Case 3: tokenFrom != nUSD && tokenTo != nUSD -> swap
            amountOut = IDefaultExtendedPool(pool).swap({
                tokenIndexFrom: tokenFrom.index,
                tokenIndexTo: tokenTo.index,
                dx: amountIn,
                minDy: 0,
                deadline: block.timestamp
            });
        }
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
        if (tokenFrom.index == NUM_TOKENS) {
            // Case 1: tokenFrom == nUSD -> remove liquidity
            amountOut = IDefaultExtendedPool(pool).calculateRemoveLiquidityOneToken({
                tokenAmount: amountIn,
                tokenIndex: tokenTo.index
            });
        } else if (tokenTo.index == NUM_TOKENS) {
            // Case 2: tokenTo == nUSD -> add liquidity
            // Need to use DefaultPoolCalc to get the precise quote
            uint256[] memory amounts = new uint256[](NUM_TOKENS);
            amounts[tokenFrom.index] = amountIn;
            amountOut = IDefaultPoolCalc(DEFAULT_POOL_CALC).calculateAddLiquidity(NEXUS_POOL, amounts);
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
        tokens = new address[](NUM_TOKENS + 1);
        for (uint256 i = 0; i < NUM_TOKENS; i++) {
            tokens[i] = IDefaultExtendedPool(pool).getToken(uint8(i));
        }
        tokens[NUM_TOKENS] = NUSD;
    }
}
