// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SwapQuery} from "../../router/libs/Structs.sol";

interface IFastBridgeRouter {
    function bridge(
        address recipient,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) external payable;

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    function getOriginAmountOut(
        address tokenIn,
        address[] memory bridgeTokens,
        uint256 amountIn
    ) external view returns (SwapQuery[] memory originQueries);
}
