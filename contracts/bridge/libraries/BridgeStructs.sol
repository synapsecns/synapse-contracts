// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

struct SwapQuery {
    address swapAdapter;
    address tokenOut;
    uint256 minAmountOut;
    uint256 deadline;
    bytes rawParams;
}

enum Action {
    Swap,
    AddLiquidity,
    RemoveLiquidity,
    HandleEth
}

/// @notice Struct representing a token, and the available Actions for performing a swap.
/// @param actionMask   Bitmask representing what actions (see ActionLib) are available for swapping a token
/// @param token        Token address
struct LimitedToken {
    uint256 actionMask;
    address token;
}

struct SynapseParams {
    Action action;
    address pool;
    uint8 tokenIndexFrom;
    uint8 tokenIndexTo;
}

struct PoolToken {
    bool isWeth;
    address token;
}

struct Pool {
    address pool;
    address lpToken;
    PoolToken[] tokens;
}

library ActionLib {
    function allActions() internal pure returns (uint256 actionMask) {
        actionMask = type(uint256).max;
    }

    function includes(uint256 actionMask, Action action) internal pure returns (bool) {
        return actionMask & mask(action) != 0;
    }

    function mask(Action action) internal pure returns (uint256) {
        return 1 << uint256(action);
    }

    function mask(Action a, Action b) internal pure returns (uint256) {
        return mask(a) | mask(b);
    }

    function mask(
        Action a,
        Action b,
        Action c
    ) internal pure returns (uint256) {
        return mask(a) | mask(b) | mask(c);
    }
}
