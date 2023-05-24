// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISaddle} from "./interfaces/ISaddle.sol";
import {TokenTree} from "./tree/TokenTree.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract UniversalSwap is TokenTree, Ownable {
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
        _addPool(nodeIndex, pool, poolModule, tokensAmount);
    }

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
        return _getMultiSwapQuote(tokenIndexFrom, tokenIndexTo, dx).amountOut;
    }

    /// @notice Wrapper for ISaddle.getToken()
    /// @param index     the index of the token
    /// @return token    address of the token at given index
    function getToken(uint8 index) external view returns (address token) {
        require(index < _nodes.length, "Out of range");
        return _nodes[index].token;
    }

    /// @notice Returns the full amount of the "token nodes" in the internal tree.
    /// Note that some of the tokens might be duplicated, as the node in the tree represents
    /// a given path frm the bridge token to the node token using a series of pools.
    function tokenNodesAmount() external view returns (uint256) {
        return _nodes.length;
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
            // TODO: implement swap using a delegate call to poolModule
        }
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Returns the amount of tokens that will be received from a single swap.
    function _getPoolQuote(
        address poolModule,
        address pool,
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        uint256 amountIn
    ) internal view override returns (uint256 amountOut) {
        if (poolModule == address(this)) {
            // Pool conforms to ISaddle interface.
            amountOut = ISaddle(pool).calculateSwap({
                tokenIndexFrom: tokenIndexes[pool][_nodes[nodeIndexFrom].token],
                tokenIndexTo: tokenIndexes[pool][_nodes[nodeIndexTo].token],
                dx: amountIn
            });
        } else {
            // TODO: get quote using delegate call to poolModule
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
            for (uint256 i = 0; i < tokensAmount; ++i) {
                tokens[i] = ISaddle(pool).getToken(uint8(i));
            }
        } else {
            // TODO: get tokens using delegate call to poolModule
        }
    }
}
