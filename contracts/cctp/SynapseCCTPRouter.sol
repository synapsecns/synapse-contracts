// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseCCTP} from "./interfaces/ISynapseCCTP.sol";
import {ISynapseCCTPFees} from "./interfaces/ISynapseCCTPFees.sol";
import {BridgeToken, DestRequest, SwapQuery, ISynapseCCTPRouter} from "./interfaces/ISynapseCCTPRouter.sol";
import {Action, DefaultParams} from "../router/libs/Structs.sol";

import {IDefaultPool} from "../router/interfaces/IDefaultPool.sol";

contract SynapseCCTPRouter is ISynapseCCTPRouter {
    address public immutable synapseCCTP;

    constructor(address _synapseCCTP) {
        synapseCCTP = _synapseCCTP;
    }

    // ════════════════════════════════════════════ BRIDGE INTERACTIONS ════════════════════════════════════════════════

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
    function getConnectedBridgeTokens(address tokenOut) external view returns (BridgeToken[] memory tokens) {
        BridgeToken[] memory cctpTokens = ISynapseCCTPFees(synapseCCTP).getBridgeTokens();
        uint256 length = cctpTokens.length;
        bool[] memory isConnected = new bool[](length);
        uint256 count = 0;
        for (uint256 i = 0; i < length; ++i) {
            address circleToken = cctpTokens[i].token;
            if (circleToken == tokenOut || _isConnected(circleToken, tokenOut)) {
                isConnected[i] = true;
                ++count;
            }
        }
        // Populate the returned array with connected tokens
        tokens = new BridgeToken[](count);
        // This will track the index of the next element to be inserted in the returned array
        count = 0;
        for (uint256 i = 0; i < length; ++i) {
            if (isConnected[i]) {
                tokens[count++] = cctpTokens[i];
            }
        }
    }

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

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Finds the quote for tokenIn -> tokenOut swap using a given pool.
    /// Note: only populates `tokenOut`, `minAmountOut` and `rawParams` fields.
    function _getAmountOut(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (SwapQuery memory query) {
        query.tokenOut = tokenOut;
        if (tokenIn == tokenOut) {
            query.minAmountOut = amountIn;
            // query.rawParams is "", indicating that no further action is required
            return query;
        }
        if (pool == address(0)) {
            // query.minAmountOut is 0, indicating that no quote was found
            // query.rawParams is "", indicating that no further action is required
            return query;
        }
        address[] memory poolTokens = _getPoolTokens(pool);
        uint256 numTokens = poolTokens.length;
        // Iterate over all valid (tokenIndexFrom, tokenIndexTo) combinations for tokenIn -> tokenOut swap
        for (uint8 tokenIndexFrom = 0; tokenIndexFrom < numTokens; ++tokenIndexFrom) {
            // We are only interested in the tokenFrom == tokenIn case
            if (poolTokens[tokenIndexFrom] != tokenIn) continue;
            for (uint8 tokenIndexTo = 0; tokenIndexTo < numTokens; ++tokenIndexTo) {
                // We are only interested in the tokenTo == tokenOut case
                if (poolTokens[tokenIndexTo] != tokenOut) continue;
                uint256 amountOut = _getPoolSwapQuote(pool, tokenIndexFrom, tokenIndexTo, amountIn);
                // Update the query if the new quote is better than the previous one
                if (amountOut > query.minAmountOut) {
                    query.minAmountOut = amountOut;
                    query.rawParams = abi.encode(DefaultParams(Action.Swap, pool, tokenIndexFrom, tokenIndexTo));
                }
            }
        }
    }

    /// @dev Checks if a token is connected to a Circle token: whether the token is in the whitelisted liquidity pool
    /// for the Circle token.
    function _isConnected(address circleToken, address token) internal view returns (bool) {
        // Get the whitelisted liquidity pool for the  Circle token
        address pool = ISynapseCCTP(synapseCCTP).circleTokenPool(circleToken);
        if (pool == address(0)) return false;
        // Iterate over pool tokens to check if the token is in the pool (meaning it is connected to the Circle token)
        for (uint8 index = 0; ; ++index) {
            try IDefaultPool(pool).getToken(index) returns (address poolToken) {
                if (poolToken == token) return true;
            } catch {
                // End of pool reached
                break;
            }
        }
        return false;
    }
}
