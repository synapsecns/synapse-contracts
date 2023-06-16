// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BridgeToken, DestRequest, SwapQuery, ISynapseCCTPRouter} from "./interfaces/ISynapseCCTPRouter.sol";

contract SynapseCCTPRouter is ISynapseCCTPRouter {
    /// @inheritdoc ISynapseCCTPRouter
    function bridge(
        address recipient,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable {}

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc ISynapseCCTPRouter
    function getConnectedBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory tokens) {}

    /// @inheritdoc ISynapseCCTPRouter
    function getOriginAmountOut(
        address tokenIn,
        string[] memory tokenSymbols,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries) {}

    /// @inheritdoc ISynapseCCTPRouter
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries)
    {}
}
