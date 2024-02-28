// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SwapQuery} from "../../router/libs/Structs.sol";

interface IFastBridgeRouter {
    /// @notice Sets the address of the FastBridge contract
    /// @dev This function is only callable by the owner
    /// @param fastBridge_      The address of the FastBridge contract
    function setFastBridge(address fastBridge_) external;

    /// @notice Sets the address of the SwapQuoter contract
    /// @dev This function is only callable by the owner
    /// @param swapQuoter_      The address of the SwapQuoter contract
    function setSwapQuoter(address swapQuoter_) external;

    /// @notice Initiate an RFQ transaction with an optional swap on origin chain,
    /// and an optional gas rebate on destination chain.
    /// @dev Note that method is payable.
    /// If token is ETH_ADDRESS, this method should be invoked with `msg.value = amountIn`.
    /// If token is ERC20, the tokens will be pulled from msg.sender (use `msg.value = 0`).
    /// Make sure to approve this contract for spending `token` beforehand.
    ///
    /// `originQuery` is supposed to be fetched using FastBridgeRouter.getOriginAmountOut().
    /// Alternatively one could use an external adapter for more complex swaps on the origin chain.
    /// `destQuery.rawParams` signals whether the user wants to receive a gas rebate on the destination chain:
    /// - If the first byte of `destQuery.rawParams` is GAS_REBATE_FLAG, the user wants to receive a gas rebate.
    /// - Otherwise, the user does not want to receive a gas rebate.
    ///
    /// Cross-chain RFQ swap will be performed between tokens: `originQuery.tokenOut` and `destQuery.tokenOut`.
    /// Note: both tokens could be ETH_ADDRESS or ERC20.
    /// Full proceeds of the origin swap are considered the bid for the cross-chain swap.
    /// `destQuery.minAmountOut` is considered the ask for the cross-chain swap.
    /// Note: applying slippage to `destQuery.minAmountOut` will result in a worse price for the user,
    /// the full Relayer quote should be used instead.
    /// @param recipient        Address to receive tokens on destination chain
    /// @param chainId          Destination chain id
    /// @param token            Initial token to be pulled from the user
    /// @param amount           Amount of the initial tokens to be pulled from the user
    /// @param originQuery      Origin swap query (see above)
    /// @param destQuery        Destination swap query (see above)
    function bridge(
        address recipient,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @notice Finds the best path between `tokenIn` and every RFQ token from the given list,
    /// treating the swap as "origin swap", without putting any restrictions on the swap.
    /// @dev Check (query.minAmountOut != 0): this is true only if the swap is possible.
    /// The returned queries with minAmountOut != 0 could be used as `originQuery` with FastBridgeRouter.
    /// Note: it is possible to form a SwapQuery off-chain using alternative SwapAdapter for the origin swap.
    /// @param tokenIn          Initial token that user wants to bridge/swap
    /// @param rfqTokens        List of RFQ tokens
    /// @param amountIn         Amount of tokens user wants to bridge/swap
    /// @return originQueries   List of structs that could be used as `originQuery` in FastBridgeRouter.
    ///                         minAmountOut and deadline fields will need to be adjusted based on the user settings.
    function getOriginAmountOut(
        address tokenIn,
        address[] memory rfqTokens,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries);

    /// @notice Magic value that indicates that the user wants to receive gas rebate on the destination chain.
    /// This is the answer to the ultimate question of life, the universe, and everything.
    function GAS_REBATE_FLAG() external view returns (bytes1);

    /// @notice Address of the FastBridge contract, used to initiate cross-chain RFQ swaps.
    function fastBridge() external view returns (address);

    /// @notice Address of the SwapQuoter contract, used to fetch quotes for the origin swap.
    function swapQuoter() external view returns (address);
}
