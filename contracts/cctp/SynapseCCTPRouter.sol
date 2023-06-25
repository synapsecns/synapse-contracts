// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseCCTP} from "./interfaces/ISynapseCCTP.sol";
import {ISynapseCCTPFees} from "./interfaces/ISynapseCCTPFees.sol";
import {BridgeToken, DestRequest, SwapQuery, ISynapseCCTPRouter} from "./interfaces/ISynapseCCTPRouter.sol";
import {ITokenMinter} from "./interfaces/ITokenMinter.sol";
import {UnknownRequestAction} from "./libs/RouterErrors.sol";
import {RequestLib} from "./libs/Request.sol";
import {MsgValueIncorrect, DefaultRouter} from "../router/DefaultRouter.sol";

import {IDefaultPool} from "../router/interfaces/IDefaultPool.sol";
import {Action, DefaultParams} from "../router/libs/Structs.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract SynapseCCTPRouter is DefaultRouter, ISynapseCCTPRouter {
    using SafeERC20 for IERC20;

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
    ) external payable {
        if (originQuery.hasAdapter()) {
            // Perform a swap using the swap adapter, set this contract as recipient
            (token, amount) = _doSwap(address(this), token, amount, originQuery);
        } else {
            // If no swap is required, msg.value must be left as zero
            if (msg.value != 0) revert MsgValueIncorrect();
            // Pull the token from the user to this contract
            amount = _pullToken(address(this), token, amount);
        }
        // Either way, this contract has `amount` worth of `token`
        (uint32 requestVersion, bytes memory swapParams) = _deriveCCTPSwapParams(destQuery);
        // Approve SynapseCCTP to spend the token
        _approveToken(token, synapseCCTP, amount);
        ISynapseCCTP(synapseCCTP).sendCircleToken({
            recipient: recipient,
            chainId: chainId,
            burnToken: token,
            amount: amount,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
    }

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
    ) external view returns (SwapQuery[] memory originQueries) {
        uint256 length = tokenSymbols.length;
        originQueries = new SwapQuery[](length);
        address tokenMinter = ISynapseCCTP(synapseCCTP).tokenMessenger().localMinter();
        for (uint256 i = 0; i < length; ++i) {
            address circleToken = ISynapseCCTPFees(synapseCCTP).symbolToToken(tokenSymbols[i]);
            address pool = ISynapseCCTP(synapseCCTP).circleTokenPool(circleToken);
            // Get the quote for tokenIn -> circleToken swap
            // Note: this only populates `tokenOut`, `minAmountOut` and `rawParams` fields.
            originQueries[i] = _getAmountOut(pool, tokenIn, circleToken, amountIn);
            // Check if the amount out is higher than the burn limit
            uint256 burnLimit = ITokenMinter(tokenMinter).burnLimitsPerMessage(circleToken);
            if (originQueries[i].minAmountOut > burnLimit) {
                // Nullify the query, leaving tokenOut intact (this allows SDK to get the bridge token address)
                originQueries[i].minAmountOut = 0;
                originQueries[i].rawParams = "";
            } else {
                // Fill the remaining fields, use this contract as "Router Adapter"
                originQueries[i].fillAdapterAndDeadline({routerAdapter: address(this)});
            }
        }
    }

    /// @inheritdoc ISynapseCCTPRouter
    function getDestinationAmountOut(DestRequest[] memory requests, address tokenOut)
        external
        view
        returns (SwapQuery[] memory destQueries)
    {
        uint256 length = requests.length;
        destQueries = new SwapQuery[](length);
        for (uint256 i = 0; i < length; ++i) {
            address circleToken = ISynapseCCTPFees(synapseCCTP).symbolToToken(requests[i].symbol);
            address pool = ISynapseCCTP(synapseCCTP).circleTokenPool(circleToken);
            // Calculate the relayer fee amount
            uint256 amountIn = requests[i].amountIn;
            uint256 feeAmount = ISynapseCCTPFees(synapseCCTP).calculateFeeAmount({
                token: circleToken,
                amount: amountIn,
                isSwap: circleToken != tokenOut
            });
            // Only populate the query if the amountIn is higher than the feeAmount
            if (amountIn > feeAmount) {
                // Get the quote for circleToken -> tokenOut swap after the fee is applied
                // Note: this only populates `tokenOut`, `minAmountOut` and `rawParams` fields.
                destQueries[i] = _getAmountOut(pool, circleToken, tokenOut, amountIn - feeAmount);
                // Fill the remaining fields, use this contract as "Router Adapter"
                destQueries[i].fillAdapterAndDeadline({routerAdapter: address(this)});
            } else {
                // Fill only tokenOut otherwise
                destQueries[i].tokenOut = tokenOut;
            }
        }
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Approves the token to be spent by the given spender indefinitely by giving infinite allowance.
    /// Doesn't modify the allowance if it's already enough for the given amount.
    function _approveToken(
        address token,
        address spender,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < amount) {
            // Reset allowance to 0 before setting it to the new value.
            if (allowance != 0) IERC20(token).safeApprove(spender, 0);
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

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

    /// @dev Derives the `swapParams` for following interaction with SynapseCCTP contract.
    function _deriveCCTPSwapParams(SwapQuery memory destQuery)
        internal
        pure
        returns (uint32 requestVersion, bytes memory swapParams)
    {
        // Check if any action was specified in `destQuery`
        if (destQuery.routerAdapter == address(0)) {
            // No action was specified, so no swap is required
            return (RequestLib.REQUEST_BASE, "");
        }
        DefaultParams memory params = abi.decode(destQuery.rawParams, (DefaultParams));
        // Check if the action is a swap
        if (params.action != Action.Swap) {
            // Actions other than swap are not supported for Circle tokens on the destination chain
            revert UnknownRequestAction();
        }
        requestVersion = RequestLib.REQUEST_SWAP;
        swapParams = RequestLib.formatSwapParams({
            tokenIndexFrom: params.tokenIndexFrom,
            tokenIndexTo: params.tokenIndexTo,
            deadline: destQuery.deadline,
            minAmountOut: destQuery.minAmountOut
        });
    }
}
