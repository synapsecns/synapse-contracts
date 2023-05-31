// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LimitedToken} from "../libs/Structs.sol";

interface IUniversalSwap {
    /// @notice Wrapper for ISaddle.swap()
    /// @param tokenIndexFrom    the token the user wants to swap from
    /// @param tokenIndexTo      the token the user wants to swap to
    /// @param dx                the amount of tokens the user wants to swap from
    /// @param minDy             the min amount the user would like to receive, or revert.
    /// @param deadline          latest timestamp to accept this transaction
    /// @return amountOut        amount of tokens bought
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256 amountOut);

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @notice Wrapper for ISaddle.calculateSwap()
    /// @param tokenIndexFrom    the token the user wants to sell
    /// @param tokenIndexTo      the token the user wants to buy
    /// @param dx                the amount of tokens the user wants to sell. If the token charges
    ///                          a fee on transfers, use the amount that gets transferred after the fee.
    /// @return amountOut        amount of tokens the user will receive
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut);

    /// @notice Wrapper for ISaddle.getToken()
    /// @param index     the index of the token
    /// @return token    address of the token at given index
    function getToken(uint8 index) external view returns (address token);

    /// @notice Checks if a it is possible to start from any of the tokens in the given list
    /// and finish with tokenOut, using any of the supported pools. Only checks the paths that start or end
    /// with a root node (the bridge token).
    /// @dev This is used by SwapQuoterV2 to find bridge tokens that could fulfill the cross-chain swap request on
    /// either origin or destination chain, meaning either `tokensIn` or `tokenOut` should be a bridge token.
    /// @param tokensIn List of structs with following information:
    ///                 - actionMask    Bitmask representing what actions are available for doing tokenIn -> tokenOut
    ///                 - token         Token address to begin from
    /// @param tokenOut Token address to end up with
    /// @return isConnected List of bool values, specifying whether a token from the list is swappable to tokenOut
    function getConnectedTokens(LimitedToken[] memory tokensIn, address tokenOut)
        external
        view
        returns (bool[] memory isConnected);

    /// @notice Returns the best path for swapping the given amount of tokens. All possible paths
    /// present in the internal tree are considered, if any of the tokens are present in the tree more than once.
    /// Note: paths that have the same pool more than once are not considered.
    /// @dev Will return zero values if no path is found.
    /// @param tokenIn          the token the user wants to sell
    /// @param tokenOut         the token the user wants to buy
    /// @param amountIn         the amount of tokens the user wants to sell
    /// @return tokenIndexFrom  the index of the token the user wants to sell
    /// @return tokenIndexTo    the index of the token the user wants to buy
    /// @return amountOut       amount of tokens the user will receive
    function findBestPath(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        external
        view
        returns (
            uint8 tokenIndexFrom,
            uint8 tokenIndexTo,
            uint256 amountOut
        );

    /// @notice Returns the full amount of the "token nodes" in the internal tree.
    /// Note that some of the tokens might be duplicated, as the node in the tree represents
    /// a given path frm the bridge token to the node token using a series of pools.
    function tokenNodesAmount() external view returns (uint256);

    /// @notice Returns the list of pools that are "attached" to a node.
    /// Pool is attached to a node, if it connects the node to one of its children.
    /// Note: pool that is connecting the node to its parent is not considered attached.
    function getAttachedPools(uint8 index) external view returns (address[] memory pools);

    /// @notice Returns all nodes that represent the given token in the internal tree.
    function getTokenNodes(address token) external view returns (uint256[] memory nodes);
}
