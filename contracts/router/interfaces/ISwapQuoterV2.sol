// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISwapQuoterV1} from "./ISwapQuoterV1.sol";
import {LimitedToken} from "../libs/Structs.sol";

interface ISwapQuoterV2 is ISwapQuoterV1 {
    /// @notice Checks if tokenIn -> tokenOut swap is possible using the supported pools.
    /// Follows `getAmountOut()` convention when it comes to providing tokenIn.actionMask:
    /// - If this is a request for the swap to be performed immediately (or the "origin swap" in the bridge workflow),
    /// `tokenIn.actionMask` needs to be set to bitmask of all possible actions (ActionLib.allActions()).
    ///  For this case, all pools added to SwapQuoterV2 will be considered for the swap.
    /// - If this is a request for the swap to be performed as the "destination swap" in the bridge workflow,
    /// `tokenIn.actionMask` needs to be set to bitmask of possible actions for `tokenIn.token` as a bridge token,
    /// e.g. Action.Swap for minted tokens, or Action.RemoveLiquidity | Action.HandleEth for withdrawn tokens.
    ///
    /// As for the pools considered for the swap, there are two cases:
    /// - If this is a request for the swap to be performed immediately (or the "origin swap" in the bridge workflow),
    /// all pools added to SwapQuoterV2 will be considered for the swap.
    /// - If this is a request for the swap to be performed as the "destination swap" in the bridge workflow,
    /// only the whitelisted pool for tokenIn.token will be considered for the swap.
    function areConnectedTokens(LimitedToken memory tokenIn, address tokenOut) external view returns (bool);

    /// @notice Allows to set the SynapseRouter contract, which is used as "Router Adapter" for doing
    /// swaps through Default Pools (or handling ETH).
    /// Note: this will not affect the old SynapseRouter contract which still uses this Quoter, as the old SynapseRouter
    /// could handle the requests with the new SynapseRouter as external "Router Adapter".
    function setSynapseRouter(address synapseRouter_) external;
}
