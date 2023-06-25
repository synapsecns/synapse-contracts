// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13; // "using A for B global" requires 0.8.13 or higher

// ══════════════════════════════════════════ TOKEN AND POOL DESCRIPTION ═══════════════════════════════════════════════

/// @notice Struct representing a bridge token. Used as the return value in view functions.
/// @param symbol   Bridge token symbol: unique token ID consistent among all chains
/// @param token    Bridge token address
struct BridgeToken {
    string symbol;
    address token;
}

/// @notice Struct used by IPoolHandler to represent a token in a pool
/// @param index    Token index in the pool
/// @param token    Token address
struct IndexedToken {
    uint8 index;
    address token;
}

/// @notice Struct representing a token, and the available Actions for performing a swap.
/// @param actionMask   Bitmask representing what actions (see ActionLib) are available for swapping a token
/// @param token        Token address
struct LimitedToken {
    uint256 actionMask;
    address token;
}

/// @notice Struct representing how pool tokens are stored by `SwapQuoter`.
/// @param isWeth   Whether the token represents Wrapped ETH.
/// @param token    Token address.
struct PoolToken {
    bool isWeth;
    address token;
}

/// @notice Struct representing a liquidity pool. Used as the return value in view functions.
/// @param pool         Pool address.
/// @param lpToken      Address of pool's LP token.
/// @param tokens       List of pool's tokens.
struct Pool {
    address pool;
    address lpToken;
    PoolToken[] tokens;
}

// ════════════════════════════════════════════════ ROUTER STRUCTS ═════════════════════════════════════════════════════

/// @notice Struct representing a quote request for swapping a bridge token.
/// Used in destination chain's SynapseRouter, hence the name "Destination Request".
/// @dev tokenOut is passed externally.
/// @param symbol   Bridge token symbol: unique token ID consistent among all chains
/// @param amountIn Amount of bridge token to start with, before the bridge fee is applied
struct DestRequest {
    string symbol;
    uint256 amountIn;
}

/// @notice Struct representing a swap request for SynapseRouter.
/// @dev tokenIn is supplied separately.
/// @param routerAdapter    Contract that will perform the swap for the Router. Address(0) specifies a "no swap" query.
/// @param tokenOut         Token address to swap to.
/// @param minAmountOut     Minimum amount of tokens to receive after the swap, or tx will be reverted.
/// @param deadline         Latest timestamp for when the transaction needs to be executed, or tx will be reverted.
/// @param rawParams        ABI-encoded params for the swap that will be passed to `routerAdapter`.
///                         Should be DefaultParams for swaps via DefaultAdapter.
struct SwapQuery {
    address routerAdapter;
    address tokenOut;
    uint256 minAmountOut;
    uint256 deadline;
    bytes rawParams;
}

// ════════════════════════════════════════════════ ADAPTER STRUCTS ════════════════════════════════════════════════════

/// @notice Struct representing parameters for swapping via DefaultAdapter.
/// @param action           Action that DefaultAdapter needs to perform.
/// @param pool             Liquidity pool that will be used for Swap/AddLiquidity/RemoveLiquidity actions.
/// @param tokenIndexFrom   Token index to swap from. Used for swap/addLiquidity actions.
/// @param tokenIndexTo     Token index to swap to. Used for swap/removeLiquidity actions.
struct DefaultParams {
    Action action;
    address pool;
    uint8 tokenIndexFrom;
    uint8 tokenIndexTo;
}

/// @notice All possible actions that DefaultAdapter could perform.
enum Action {
    Swap, // swap between two pools tokens
    AddLiquidity, // add liquidity in a form of a single pool token
    RemoveLiquidity, // remove liquidity in a form of a single pool token
    HandleEth // ETH <> WETH interaction
}

using ActionLib for Action global;

/// @notice Library for dealing with bit masks which describe what set of Actions is available.
library ActionLib {
    /// @notice Returns a bitmask with all possible actions set to True.
    function allActions() internal pure returns (uint256 actionMask) {
        actionMask = type(uint256).max;
    }

    /// @notice Returns whether the given action is set to True in the bitmask.
    function isIncluded(Action action, uint256 actionMask) internal pure returns (bool) {
        return actionMask & mask(action) != 0;
    }

    /// @notice Returns a bitmask with only the given action set to True.
    function mask(Action action) internal pure returns (uint256) {
        return 1 << uint256(action);
    }

    /// @notice Returns a bitmask with only two given actions set to True.
    function mask(Action a, Action b) internal pure returns (uint256) {
        return mask(a) | mask(b);
    }
}
