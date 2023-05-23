// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract UniversalSwap {
    /// @notice Struct so store the tree nodes
    /// @param token        Address of the token represented by this node
    /// @param depth        Depth of the node in the tree
    /// @param parentPool   Index of the pool that connects this node to its parent (0 if root)
    struct Node {
        address token;
        uint8 depth;
        uint8 parentPool;
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
    // - For a node at depth N, lowest (N + 1) bytes are used to store the path to the root.
    // - The lowest byte is always the root index. This is always 0, but we store this for consistency.
    // - The highest byte is always the node index.
    // - The remaining bytes are indexes of the nodes on the path from the node to the root (from highest to lowest).
    // This way the finding the lowest common ancestor of two nodes is reduced to finding the first differing byte.
    uint256[] internal _rootPath;

    // ════════════════════════════════════════════════ CONSTRUCTOR ════════════════════════════════════════════════════

    constructor(address bridgeToken) {
        // The root node is always the bridge token
        _nodes.push(Node({token: bridgeToken, depth: 0, parentPool: 0}));
        // Push the empty pool so that `parentPool` for non-root nodes is never 0
        _pools.push(address(0));
        // _rootPath for the root is always 0, so we can skip it
    }

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
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        // Check if either of the nodes is the root
        Node memory nodeTo = _nodes[nodeIndexTo];
        uint256 rootPathTo = _rootPath[nodeIndexTo];
        Node memory nodeFrom = _nodes[nodeIndexFrom];
        uint256 rootPathFrom = _rootPath[nodeIndexFrom];
        // Find the depth where the paths diverge
        uint256 depthDiff = _depthDiff(rootPathFrom, rootPathTo);
        // Check that the nodes are not on the same branch
        if (depthDiff > nodeTo.depth) {
            // Path from "tokenFrom" to root includes "tokenTo",
            // so we simply go from "tokenFrom" to "tokenTo" in the "to root" direction.
            (, amountOut) = _getMultiQuoteToRoot(rootPathFrom, nodeFrom.depth, nodeTo.depth, amountIn);
            return amountOut;
        }
        if (depthDiff > nodeFrom.depth) {
            // Path from "tokenTo" to root includes "tokenFrom",
            // so we simply go from "tokenTo" to "tokenFrom" in the "from root" direction.
            (, amountOut) = _getMultiQuoteFromRoot(rootPathTo, nodeFrom.depth, nodeTo.depth, amountIn);
            return amountOut;
        }
        // First, we traverse up the tree from "tokenFrom" to one level deeper the lowest common ancestor.
        (nodeIndexFrom, amountOut) = _getMultiQuoteToRoot(rootPathFrom, nodeFrom.depth, depthDiff, amountIn);
        // Check if we need to do a sibling swap. When the two nodes are connected to the same parent via the same pool,
        // we need to do a direct swap between the two nodes, instead of going through the parent.
        uint256 siblingIndex = _extractNodeIndex(rootPathTo, depthDiff);
        uint256 firstPoolIndex = _nodes[nodeIndexFrom].parentPool;
        uint256 secondPoolIndex = _nodes[siblingIndex].parentPool;
        if (firstPoolIndex == secondPoolIndex) {
            // Swap nodeIndexFrom -> siblingIndex
            amountOut = _getSimpleQuote(firstPoolIndex, nodeIndexFrom, siblingIndex, amountOut);
        } else {
            // Swap nodeIndexFrom -> parentIndex
            uint256 parentIndex = _extractNodeIndex(rootPathFrom, depthDiff - 1);
            amountOut = _getSimpleQuote(firstPoolIndex, nodeIndexFrom, parentIndex, amountOut);
            // Swap parentIndex -> siblingIndex
            amountOut = _getSimpleQuote(secondPoolIndex, parentIndex, siblingIndex, amountOut);
        }
        // Finally, we traverse down the tree from the lowest common ancestor to "tokenTo".
        (, amountOut) = _getMultiQuoteFromRoot(rootPathTo, depthDiff, nodeTo.depth, amountOut);
    }

    /**
     * @dev Calculates the amount of tokens that will be received from a multi-hop swap,
     * when going in "from root direction" via the given `rootPath` from `depthFrom` to `depthTo`.
     */
    function _getMultiQuoteFromRoot(
        uint256 rootPath,
        uint256 depthFrom,
        uint256 depthTo,
        uint256 amountIn
    ) internal view returns (uint256 nodeIndex, uint256 amountOut) {
        nodeIndex = _extractNodeIndex(rootPath, depthFrom);
        amountOut = amountIn;
        // Traverse down the tree following `rootPath` from `depthFrom` to `depthTo`.
        for (uint256 depth = depthFrom; depth < depthTo; ) {
            // Get the child node
            ++depth;
            uint256 childIndex = _extractNodeIndex(rootPath, depth);
            // Swap nodeIndex -> childIndex
            amountOut = _getSimpleQuote(_nodes[childIndex].parentPool, nodeIndex, childIndex, amountOut);
            nodeIndex = childIndex;
        }
    }

    /**
     * @dev Calculates the amount of tokens that will be received from a multi-hop swap,
     * when going in "to root direction" via the given `rootPath` from `depthFrom` to `depthTo`.
     */
    function _getMultiQuoteToRoot(
        uint256 rootPath,
        uint256 depthFrom,
        uint256 depthTo,
        uint256 amountIn
    ) internal view returns (uint256 nodeIndex, uint256 amountOut) {
        nodeIndex = _extractNodeIndex(rootPath, depthFrom);
        amountOut = amountIn;
        // Traverse up the tree following `rootPath` from `depthFrom` to `depthTo`.
        for (uint256 depth = depthFrom; depth > depthTo; ) {
            // Get the parent node
            --depth;
            uint256 parentIndex = _extractNodeIndex(rootPath, depth);
            // Swap nodeIndex -> parentIndex
            amountOut = _getSimpleQuote(_nodes[nodeIndex].parentPool, nodeIndex, parentIndex, amountOut);
            nodeIndex = parentIndex;
        }
    }

    /**
     * @dev Calculates the amount of tokens that will be received from a simple swap.
     */
    function _getSimpleQuote(
        uint256 poolIndex,
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        // TODO: get quote using poolLogic[poolIndex]
    }

    /**
     * @dev Finds the lowest common ancestor of two different nodes in the tree.
     * Node is defined by the path from the root to the node, and the depth of the node.
     */
    function _depthDiff(uint256 rootPath0, uint256 rootPath1) internal pure returns (uint256 depthDiff) {
        // Xor the paths to get the first differing byte. Values are different, so the result is never zero.
        rootPath0 ^= rootPath1;
        // Sanity check for invariant: rootPath0 != rootPath1
        assert(rootPath0 != 0);
        // Traverse from root to node0 and node1 until the paths diverge.
        while ((rootPath0 & 0xFF) == 0) {
            // Shift off the lowest byte which are identical in both paths.
            rootPath0 >>= 8;
            depthDiff++;
        }
    }

    /**
     * @dev Returns the index of the node at the given depth on the path from the root to the node.
     */
    function _extractNodeIndex(uint256 rootPath, uint256 depth) internal pure returns (uint256 nodeIndex) {
        // Nodes on the path are stored from root to node (lowest to highest bytes).
        return (rootPath >> (8 * depth)) & 0xFF;
    }
}
