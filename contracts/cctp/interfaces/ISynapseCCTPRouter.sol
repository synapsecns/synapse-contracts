// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BridgeToken, DestRequest, SwapQuery} from "../../router/libs/Structs.sol";

interface ISynapseCCTPRouter {
    /// @notice Initiate a bridge transaction with an optional swap on both origin and destination chains.
    /// @dev Note that method is payable.
    /// If token is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
    /// If token is ERC20, the tokens will be pulled from msg.sender (use `msg.value = 0`).
    /// Make sure to approve this contract for spending `token` beforehand.
    /// originQuery.tokenOut should never be ETH_ADDRESS, bridge only works with ERC20 tokens.
    ///
    /// `originQuery` is supposed to be fetched using Router.getOriginAmountOut().
    /// Alternatively one could use an external adapter for more complex swaps on the origin chain.
    ///
    /// `destQuery` is supposed to be fetched using Router.getDestinationAmountOut().
    /// Complex swaps on destination chain are not supported for the time being.
    /// @param recipient    Address to receive tokens on destination chain
    /// @param chainId      Destination chain id
    /// @param token        Initial token for the bridge transaction to be pulled from the user
    /// @param amount       Amount of the initial tokens for the bridge transaction
    /// @param originQuery  Origin swap query. Empty struct indicates no swap is required
    /// @param destQuery    Destination swap query. Empty struct indicates no swap is required
    function bridge(
        address recipient,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @notice Gets the list of all bridge tokens (and their symbols), such that destination swap
    /// from a bridge token to `tokenOut` is possible.
    /// @param tokenOut  Token address to swap to on destination chain
    /// @return tokens   List of structs with following information:
    ///                  - symbol: unique token ID consistent among all chains
    ///                  - token: bridge token address
    function getConnectedBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory tokens);

    /// @notice Finds the best path between `tokenIn` and every supported bridge token from the given list,
    /// treating the swap as "origin swap", without putting any restrictions on the swap.
    /// @dev Will NOT revert if any of the tokens are not supported, instead will return an empty query for that symbol.
    /// Check (query.minAmountOut != 0): this is true only if the swap is possible and bridge token is supported.
    /// The returned queries with minAmountOut != 0 could be used as `originQuery` with SynapseRouter.
    /// Note: it is possible to form a SwapQuery off-chain using alternative SwapAdapter for the origin swap.
    /// @param tokenIn       Initial token that user wants to bridge/swap
    /// @param tokenSymbols  List of symbols representing bridge tokens
    /// @param amountIn      Amount of tokens user wants to bridge/swap
    /// @return originQueries    List of structs that could be used as `originQuery` in SynapseRouter.
    ///                          minAmountOut and deadline fields will need to be adjusted based on the user settings.
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries);

    /// @notice Finds the best path between every supported bridge token from the given list and `tokenOut`,
    /// treating the swap as "destination swap", limiting possible actions to those available for every bridge token.
    /// @dev Will NOT revert if any of the tokens are not supported, instead will return an empty query for that symbol.
    /// Note: it is NOT possible to form a SwapQuery off-chain using alternative SwapAdapter for the destination swap.
    /// For the time being, only swaps through the Synapse-supported pools are available on destination chain.
    /// @param requests  List of structs with following information:
    ///                  - symbol: unique token ID consistent among all chains
    ///                  - amountIn: amount of bridge token to start with, before the bridge fee is applied
    /// @param tokenOut  Token user wants to receive on destination chain
    /// @return destQueries  List of structs that could be used as `destQuery` in SynapseRouter.
    ///                      minAmountOut and deadline fields will need to be adjusted based on the user settings.
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries);
}
