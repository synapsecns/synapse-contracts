// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISaddle} from "./interfaces/ISaddle.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract UniversalSwap is Ownable {
    /// @notice Struct so store the tree nodes
    /// @param token        Address of the token represented by this node
    /// @param depth        Depth of the node in the tree
    /// @param parentPool   Index of the pool that connects this node to its parent (0 if root)
    struct Node {
        address token;
        uint8 depth;
        uint8 parentPool;
    }

    /// @notice Struct to store the liquidity pools
    /// @dev Logic address is used for delegate calls to get swap quotes, token indexes, etc.
    /// Set to address(this) if pool conforms to ISaddle interface. Set to 0x0 if pool is not supported.
    /// @param logic        Address of the logic contract for this pool
    /// @param poolIndex    Index of the pool in the `_pools` array
    struct Pool {
        address logic;
        uint8 poolIndex;
    }

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    // The nodes of the tree are stored in an array. The root node is at index 0.
    Node[] internal _nodes;

    // The list of all supported liquidity pools. All values are unique.
    address[] internal _pools;

    // (pool address => pool description)
    mapping(address => Pool) internal _poolMap;

    // (pool => token => tokenIndex) for each pool, stores the index of each token in the pool.
    mapping(address => mapping(address => uint8)) public tokenIndexes;

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
     * @notice Adds a pool with `N = tokensAmount` tokens to the tree by adding N-1 new nodes
     * as the children of the given node. Given node needs to represent a token from the pool.
     */
    function addPool(
        uint256 nodeIndex,
        address pool,
        address poolLogic,
        uint256 tokensAmount
    ) external onlyOwner {
        require(nodeIndex < _nodes.length, "Out of range");
        Node memory node = _nodes[nodeIndex];
        if (poolLogic == address(0)) poolLogic = address(this);
        (bool wasAdded, uint8 poolIndex) = _addPool(pool, poolLogic);
        address[] memory tokens = _getPoolTokens(poolLogic, pool, tokensAmount);
        bool nodeFound = false;
        uint8 childDepth = node.depth + 1;
        for (uint256 i = 0; i < tokensAmount; ++i) {
            address token = tokens[i];
            // Save token indexes if this is a new pool
            if (wasAdded) {
                tokenIndexes[pool][token] = uint8(i);
            }
            // Add new nodes to the tree
            if (token == node.token) {
                // TODO: check that pool wasn't added twice to the same node
                nodeFound = true;
                continue;
            }
            _nodes.push(Node({token: token, depth: childDepth, parentPool: poolIndex}));
        }
        require(nodeFound, "Node token not found in the pool");
    }

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
        amountOut = _multiSwap(tokenIndexFrom, tokenIndexTo, dx);
        require(amountOut >= minDy, "Swap didn't result in min tokens");
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

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /**
     * @dev Adds pool to the list of pools, if it hasn't been added yet.
     */
    function _addPool(address pool, address poolLogic) internal returns (bool wasAdded, uint8 poolIndex) {
        if (_poolMap[pool].logic != address(0)) {
            return (false, _poolMap[pool].poolIndex);
        }
        wasAdded = true;
        poolIndex = uint8(_pools.length);
        _pools.push(pool);
        _poolMap[pool] = Pool({logic: poolLogic, poolIndex: uint8(poolIndex)});
    }

    /**
     * @dev Performs a multi-hop swap by following the path from "tokenFrom" node to "tokenTo" node
     * in the stored tree. Token indexes are checked to be within range and not the same.
     */
    function _multiSwap(
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
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
            (, amountOut) = _multiSwapToRoot(rootPathFrom, nodeFrom.depth, nodeTo.depth, amountIn);
            return amountOut;
        }
        if (depthDiff > nodeFrom.depth) {
            // Path from "tokenTo" to root includes "tokenFrom",
            // so we simply go from "tokenTo" to "tokenFrom" in the "from root" direction.
            (, amountOut) = _multiSwapFromRoot(rootPathTo, nodeFrom.depth, nodeTo.depth, amountIn);
            return amountOut;
        }
        // First, we traverse up the tree from "tokenFrom" to one level deeper the lowest common ancestor.
        (nodeIndexFrom, amountOut) = _multiSwapToRoot(rootPathFrom, nodeFrom.depth, depthDiff, amountIn);
        // Check if we need to do a sibling swap. When the two nodes are connected to the same parent via the same pool,
        // we need to do a direct swap between the two nodes, instead of going through the parent.
        uint256 siblingIndex = _extractNodeIndex(rootPathTo, depthDiff);
        uint256 firstPoolIndex = _nodes[nodeIndexFrom].parentPool;
        uint256 secondPoolIndex = _nodes[siblingIndex].parentPool;
        if (firstPoolIndex == secondPoolIndex) {
            // Swap nodeIndexFrom -> siblingIndex
            amountOut = _simpleSwap(firstPoolIndex, nodeIndexFrom, siblingIndex, amountOut);
        } else {
            // Swap nodeIndexFrom -> parentIndex
            uint256 parentIndex = _extractNodeIndex(rootPathFrom, depthDiff - 1);
            amountOut = _simpleSwap(firstPoolIndex, nodeIndexFrom, parentIndex, amountOut);
        }
        // Finally, we traverse down the tree from the lowest common ancestor to "tokenTo".
        (, amountOut) = _multiSwapFromRoot(rootPathTo, depthDiff, nodeTo.depth, amountOut);
    }

    /**
     * @dev Performs a multi-hop swap,
     * going in "from root direction" via the given `rootPath` from `depthFrom` to `depthTo`.
     */
    function _multiSwapFromRoot(
        uint256 rootPath,
        uint256 depthFrom,
        uint256 depthTo,
        uint256 amountIn
    ) internal returns (uint256 nodeIndex, uint256 amountOut) {
        nodeIndex = _extractNodeIndex(rootPath, depthFrom);
        amountOut = amountIn;
        // Traverse up the tree following `rootPath` from `depthFrom` to `depthTo`.
        for (uint256 depth = depthFrom; depth > depthTo; ) {
            // Get the parent node
            --depth;
            uint256 parentIndex = _extractNodeIndex(rootPath, depth);
            // Swap nodeIndex -> parentIndex
            amountOut = _simpleSwap(_nodes[nodeIndex].parentPool, nodeIndex, parentIndex, amountOut);
            nodeIndex = parentIndex;
        }
    }

    /**
     * @dev Performs a multi-hop swap,
     * going in "to root direction" via the given `rootPath` from `depthFrom` to `depthTo`.
     */
    function _multiSwapToRoot(
        uint256 rootPath,
        uint256 depthFrom,
        uint256 depthTo,
        uint256 amountIn
    ) internal returns (uint256 nodeIndex, uint256 amountOut) {
        nodeIndex = _extractNodeIndex(rootPath, depthFrom);
        amountOut = amountIn;
        // Traverse down the tree following `rootPath` from `depthFrom` to `depthTo`.
        for (uint256 depth = depthFrom; depth < depthTo; ) {
            // Get the child node
            ++depth;
            uint256 childIndex = _extractNodeIndex(rootPath, depth);
            // Swap nodeIndex -> childIndex
            amountOut = _simpleSwap(_nodes[childIndex].parentPool, nodeIndex, childIndex, amountOut);
            nodeIndex = childIndex;
        }
    }

    /**
     * @dev Performs a simple swap between two nodes using the given pool.
     */
    function _simpleSwap(
        uint256 poolIndex,
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        address pool = _pools[poolIndex];
        address poolLogic = _poolMap[pool].logic;
        if (poolLogic == address(this)) {
            // Pool conforms to ISaddle interface. Note: we check minDy and deadline outside of this function.
            amountOut = ISaddle(pool).swap({
                tokenIndexFrom: tokenIndexes[pool][_nodes[nodeIndexFrom].token],
                tokenIndexTo: tokenIndexes[pool][_nodes[nodeIndexTo].token],
                dx: amountIn,
                minDy: 0,
                deadline: type(uint256).max
            });
        } else {
            // TODO: implement swap using a delegate call to poolLogic
        }
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
        address pool = _pools[poolIndex];
        address poolLogic = _poolMap[pool].logic;
        if (poolLogic == address(this)) {
            // Pool conforms to ISaddle interface.
            amountOut = ISaddle(pool).calculateSwap({
                tokenIndexFrom: tokenIndexes[pool][_nodes[nodeIndexFrom].token],
                tokenIndexTo: tokenIndexes[pool][_nodes[nodeIndexTo].token],
                dx: amountIn
            });
        } else {
            // TODO: get quote using delegate call to poolLogic
        }
    }

    /**
     * @dev Returns the tokens in the pool at the given address.
     */
    function _getPoolTokens(
        address poolLogic,
        address pool,
        uint256 tokensAmount
    ) internal view returns (address[] memory tokens) {
        if (poolLogic == address(this)) {
            // Pool conforms to ISaddle interface.
            tokens = new address[](tokensAmount);
            for (uint256 i = 0; i < tokensAmount; ++i) {
                tokens[i] = ISaddle(pool).getToken(uint8(i));
            }
        } else {
            // TODO: get tokens using delegate call to poolLogic
        }
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
