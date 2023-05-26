// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IPausable} from "./interfaces/IPausable.sol";
import {IndexedToken, IPoolModule} from "./interfaces/IPoolModule.sol";
import {IUniversalSwap} from "./interfaces/IUniversalSwap.sol";
import {ISaddle} from "./interfaces/ISaddle.sol";
import {TokenTree} from "./tree/TokenTree.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

/// UniversalSwap is using an internal Token Tree to aggregate a collection of pools with correlated
/// tokens into a single wrapper, conforming to ISaddle interface.
/// The internal Token Tree allows to store up to 256 tokens, which should be enough for most use cases.
/// Note: unlike traditional Saddle pools, tokens in UniversalSwap could be duplicated.
/// This contract is supposed to be used in conjunction with Synapse:Bridge:
/// - The bridged token has index == 0, and could not be duplicated in the tree.
/// - Other tokens (correlated to bridge token) could be duplicated in the tree. Every node token in the tree
/// is represented by a trade path from root token to node token.
/// > This is the reason why token could be duplicated. `nUSD -> USDC` and `nUSD -> USDT -> USDC` both represent
/// > USDC token, but via different paths from nUSD, the bridge token.
/// In addition to the standard ISaddle interface, UniversalSwap also implements getters to observe the internal
/// tree, as well as the best path finder between any two tokens in the tree.
contract UniversalSwap is TokenTree, Ownable, IUniversalSwap {
    using SafeERC20 for IERC20;

    // solhint-disable-next-line no-empty-blocks
    constructor(address bridgeToken) TokenTree(bridgeToken) {}

    // ═════════════════════════════════════════════════ EXTERNAL ══════════════════════════════════════════════════════

    /// @notice Adds a pool with `N = tokensAmount` tokens to the tree by adding N-1 new nodes
    /// as the children of the given node. Given node needs to represent a token from the pool.
    /// @dev `poolModule` should be set to address(this) if the pool conforms to ISaddle interface.
    /// Otherwise, it should be set to the address of the contract that implements the logic for pool handling.
    /// @param nodeIndex        The index of the node to which the pool will be added
    /// @param pool             The address of the pool
    /// @param poolModule       The address of the pool module
    /// @param tokensAmount     The amount of tokens in the pool
    function addPool(
        uint256 nodeIndex,
        address pool,
        address poolModule,
        uint256 tokensAmount
    ) external onlyOwner {
        require(pool != address(0), "Pool address can't be zero");
        _addPool(nodeIndex, pool, poolModule, tokensAmount);
    }

    /// @inheritdoc IUniversalSwap
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
        // Pull initial token from the user
        IERC20(_nodes[tokenIndexFrom].token).safeTransferFrom(msg.sender, address(this), dx);
        amountOut = _multiSwap(tokenIndexFrom, tokenIndexTo, dx).amountOut;
        require(amountOut >= minDy, "Swap didn't result in min tokens");
        // Transfer the tokens to the user
        IERC20(_nodes[tokenIndexTo].token).safeTransfer(msg.sender, amountOut);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IUniversalSwap
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
        // Calculate the quote by following the path from "tokenFrom" node to "tokenTo" node in the stored tree
        // This function might be called by Synapse:Bridge before the swap, so we don't waste gas checking if pool is paused,
        // as the swap will fail anyway if it is.
        amountOut = _getMultiSwapQuote({
            nodeIndexFrom: tokenIndexFrom,
            nodeIndexTo: tokenIndexTo,
            amountIn: dx,
            probePaused: false
        }).amountOut;
    }

    /// Note: this could be potentially a gas expensive operation. This should be used as an off-chain call
    /// to get the best quote. As pair of token nodes define a single trade path, it will be possible to go
    /// through the found path by simply supplying the found indexes (instead of searching for the best path again).
    /// @inheritdoc IUniversalSwap
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
        )
    {
        // Check that the tokens are not the same and that the amount is not zero
        if (tokenIn == tokenOut || amountIn == 0) {
            return (0, 0, 0);
        }
        uint256 nodesFrom = _tokenNodes[tokenIn].length;
        uint256 nodesTo = _tokenNodes[tokenOut].length;
        // Go through every node that represents `tokenIn`
        for (uint256 i = 0; i < nodesFrom; ++i) {
            uint256 nodeIndexFrom = _tokenNodes[tokenIn][i];
            // Go through every node that represents `tokenOut`
            for (uint256 j = 0; j < nodesTo; ++j) {
                uint256 nodeIndexTo = _tokenNodes[tokenOut][j];
                // Calculate the quote by following the path from "tokenFrom" node to "tokenTo" node in the stored tree
                // We discard any paths with paused pools, as it's not possible to swap via them anyway.
                uint256 amountOutQuote = _getMultiSwapQuote({
                    nodeIndexFrom: nodeIndexFrom,
                    nodeIndexTo: nodeIndexTo,
                    amountIn: amountIn,
                    probePaused: true
                }).amountOut;
                if (amountOutQuote > amountOut) {
                    amountOut = amountOutQuote;
                    tokenIndexFrom = uint8(nodeIndexFrom);
                    tokenIndexTo = uint8(nodeIndexTo);
                }
            }
        }
    }

    /// @inheritdoc IUniversalSwap
    function getToken(uint8 index) external view returns (address token) {
        require(index < _nodes.length, "Out of range");
        return _nodes[index].token;
    }

    /// @inheritdoc IUniversalSwap
    function tokenNodesAmount() external view returns (uint256) {
        return _nodes.length;
    }

    /// @inheritdoc IUniversalSwap
    function getAttachedPools(uint8 index) external view returns (address[] memory pools) {
        require(index < _nodes.length, "Out of range");
        pools = new address[](_pools.length);
        uint256 amountAttached = 0;
        uint256 poolsMask = _attachedPools[index];
        for (uint256 i = 0; i < pools.length; ) {
            // Check if _pools[i] is attached to the node at `index`
            unchecked {
                if ((poolsMask >> i) & 1 == 1) {
                    pools[amountAttached++] = _pools[i];
                }
                ++i;
            }
        }
        // Use assembly to shrink the array to the actual size
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(pools, amountAttached)
        }
    }

    /// @inheritdoc IUniversalSwap
    function getTokenNodes(address token) external view returns (uint256[] memory nodes) {
        nodes = _tokenNodes[token];
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Approves the given spender to spend the given token indefinitely.
    /// Note: doesn't do anything if the spender already has infinite allowance.
    function _approveToken(address token, address spender) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance != type(uint256).max) {
            // if allowance is neither zero nor infinity, reset if first
            if (allowance != 0) {
                IERC20(token).safeApprove(spender, 0);
            }
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    /// @dev Performs a single swap between two nodes using the given pool.
    /// Assumes that the initial token is already in this contract.
    function _poolSwap(
        address poolModule,
        address pool,
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn
    ) internal override returns (uint256 amountOut) {
        address tokenFrom = _nodes[nodeIndexFrom].token;
        address tokenTo = _nodes[nodeIndexTo].token;
        // Approve pool to spend the token, if needed
        if (poolModule == address(this)) {
            _approveToken({token: tokenFrom, spender: pool});
            // Pool conforms to ISaddle interface. Note: we check minDy and deadline outside of this function.
            amountOut = ISaddle(pool).swap({
                tokenIndexFrom: tokenIndexes[pool][tokenFrom],
                tokenIndexTo: tokenIndexes[pool][tokenTo],
                dx: amountIn,
                minDy: 0,
                deadline: type(uint256).max
            });
        } else {
            // poolSwap(pool, tokenFrom, tokenTo, amountIn)
            bytes memory payload = abi.encodeWithSelector(
                IPoolModule.poolSwap.selector,
                pool,
                IndexedToken({index: tokenIndexes[pool][tokenFrom], token: tokenFrom}),
                IndexedToken({index: tokenIndexes[pool][tokenTo], token: tokenTo}),
                amountIn
            );
            // Delegate swap logic to Pool Module. It should approve the pool to spend the token, if needed.
            // Note that poolModule address is set by the contract owner, so it's safe to delegatecall it.
            (bool success, bytes memory result) = poolModule.delegatecall(payload);
            require(success, "Swap failed");
            amountOut = abi.decode(result, (uint256));
        }
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Returns the amount of tokens that will be received from a single swap.
    function _getPoolQuote(
        address poolModule,
        address pool,
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn,
        bool probePaused
    ) internal view override returns (uint256 amountOut) {
        if (poolModule == address(this)) {
            // Check if pool is paused, if requested
            if (probePaused) {
                // We issue a static call in case the pool does not conform to IPausable interface.
                (bool success, bytes memory returnData) = pool.staticcall(
                    abi.encodeWithSelector(IPausable.paused.selector)
                );
                if (success && abi.decode(returnData, (bool))) {
                    // Pool is paused, return zero
                    return 0;
                }
            }
            // Pool conforms to ISaddle interface.
            try
                ISaddle(pool).calculateSwap({
                    tokenIndexFrom: tokenIndexes[pool][_nodes[nodeIndexFrom].token],
                    tokenIndexTo: tokenIndexes[pool][_nodes[nodeIndexTo].token],
                    dx: amountIn
                })
            returns (uint256 amountOut_) {
                amountOut = amountOut_;
            } catch {
                // Return zero if the pool getter reverts for any reason
                amountOut = 0;
            }
        } else {
            // Ask Pool Module to calculate the quote
            address tokenFrom = _nodes[nodeIndexFrom].token;
            address tokenTo = _nodes[nodeIndexTo].token;
            try
                IPoolModule(poolModule).getPoolQuote(
                    pool,
                    IndexedToken({index: tokenIndexes[pool][tokenFrom], token: tokenFrom}),
                    IndexedToken({index: tokenIndexes[pool][tokenTo], token: tokenTo}),
                    amountIn,
                    probePaused
                )
            returns (uint256 amountOut_) {
                amountOut = amountOut_;
            } catch {
                // Return zero if the pool module getter reverts for any reason
                amountOut = 0;
            }
        }
    }

    /// @dev Returns the tokens in the pool at the given address.
    function _getPoolTokens(
        address poolModule,
        address pool,
        uint256 tokensAmount
    ) internal view override returns (address[] memory tokens) {
        if (poolModule == address(this)) {
            // Pool conforms to ISaddle interface.
            tokens = new address[](tokensAmount);
            for (uint256 i = 0; i < tokensAmount; ) {
                tokens[i] = ISaddle(pool).getToken(uint8(i));
                unchecked {
                    ++i;
                }
            }
        } else {
            // Ask Pool Module to return the tokens
            tokens = IPoolModule(poolModule).getPoolTokens(pool, tokensAmount);
        }
    }
}
