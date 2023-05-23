// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract UniversalSwap {
    struct Node {
        address token;
        uint8 depth;
    }

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    // The nodes of the tree are stored in an array. The root node is at index 0.
    Node[] internal _nodes;

    // The list of all supported liquidity pools. All values are unique.
    address[] internal _pools;

    // Logic address for each pool. Will be used for delegate calls to get swap quotes, token indexes, etc.
    // Set to address(this) if pool conforms to ISaddle interface. Set to 0x0 if pool is not supported.
    mapping(address => address) public poolLogic;

    // The full path from every node to the root is stored using bitmasks in the following way:
    // - For a node at depth N, lowest 2*N bytes are used to store the path to the root.
    // - (parentIndex, poolIndex) are stored for every step in the path (occupying 2 bytes per step).
    // - `parentIndex` is the index of the parent node in the `_nodes` array.
    // - `poolIndex` is the index of the pool in `_pools` that contains both the parent and the current node.
    uint256[] internal _rootPath;

    // ═════════════════════════════════════════════════ EXTERNAL ══════════════════════════════════════════════════════

    /**
     * @notice Wrapper for ISaddle.swap()
     * @param tokenIndexFrom    the token the user wants to swap from
     * @param tokenIndexTo      the token the user wants to swap to
     * @param dx                the amount of tokens the user wants to swap from
     * @param minDy             the min amount the user would like to receive, or revert.
     * @param deadline          latest timestamp to accept this transaction
     * @return amountOut        amount of tokens bought
     */
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        uint256 totalTokens = _nodes.length;
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "Deadline not met");
        require(
            tokenIndexFrom < totalTokens && tokenIndexTo < totalTokens && tokenIndexFrom != tokenIndexTo,
            "Swap not supported"
        );
        // TODO: traverse from "tokenFrom" to lowest common ancestor, then from lowest common ancestor to "tokenTo"
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /**
     * @notice Wrapper for ISaddle.calculateSwap()
     * @param tokenIndexFrom    the token the user wants to sell
     * @param tokenIndexTo      the token the user wants to buy
     * @param dx                the amount of tokens the user wants to sell. If the token charges
     *                          a fee on transfers, use the amount that gets transferred after the fee.
     * @return amountOut        amount of tokens the user will receive
     */
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 amountOut) {
        uint256 totalTokens = _nodes.length;
        // Check that the token indexes are within range
        if (tokenIndexFrom >= totalTokens || tokenIndexTo >= totalTokens) {
            return 0;
        }
        // Check that the token indexes are not the same
        if (tokenIndexFrom == tokenIndexTo) {
            return 0;
        }
        return _calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    /**
     * @notice Wrapper for ISaddle.getToken()
     * @param index     the index of the token
     * @return token    address of the token at given index
     */
    function getToken(uint8 index) external view returns (address token) {
        require(index < _nodes.length, "Out of range");
        return _nodes[index].token;
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /**
     * @dev Calculates the multi-hop swap quote by following the path from "tokenFrom" node to "tokenTo" node
     * in the stored tree. Token indexes are checked to be within range and not the same.
     */
    function _calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) internal view returns (uint256 amountOut) {
        // TODO: traverse from "tokenFrom" to lowest common ancestor, then from lowest common ancestor to "tokenTo"
    }
}
