// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OnlyDelegateCall} from "../pool/OnlyDelegateCall.sol";
import {IBridgeModule} from "../../interfaces/IBridgeModule.sol";
import {IPausable} from "../../interfaces/IPausable.sol";
import {Action, BridgeToken, DefaultParams, SwapQuery} from "../../libs/Structs.sol";
import {UniversalTokenLib} from "../../libs/UniversalToken.sol";

import {RequestLib} from "../../../cctp/libs/Request.sol";
import {ISynapseCCTP} from "../../../cctp/interfaces/ISynapseCCTP.sol";
import {ISynapseCCTPFees} from "../../../cctp/interfaces/ISynapseCCTPFees.sol";
import {ITokenMinter} from "../../../cctp/interfaces/ITokenMinter.sol";

contract SynapseCCTPModule is OnlyDelegateCall, IBridgeModule {
    using UniversalTokenLib for address;

    error SynapseCCTPModule__EqualSwapIndexes(uint8 index);
    error SynapseCCTPModule__UnsupportedAction(Action action);
    error SynapseCCTPModule__UnsupportedToken(address token);

    /// These need to be immutable in order to be accessed via delegatecall
    address public immutable synapseCCTP;

    constructor(address synapseCCTP_) {
        synapseCCTP = synapseCCTP_;
    }

    /// @inheritdoc IBridgeModule
    function delegateBridge(
        address to,
        uint256 chainId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) external payable {
        assertDelegateCall();
        // Revert if the token is not supported
        if (!_isSupported(token)) revert SynapseCCTPModule__UnsupportedToken(token);
        (uint32 requestVersion, bytes memory swapParams) = _deriveCCTPSwapParams(destQuery);
        // Approve SynapseCCTP to spend the token
        token.universalApproveInfinity({spender: synapseCCTP, amountToSpend: amount});
        ISynapseCCTP(synapseCCTP).sendCircleToken({
            recipient: to,
            chainId: chainId,
            burnToken: token,
            amount: amount,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IBridgeModule
    function getMaxBridgedAmount(address token) external view returns (uint256 amount) {
        // Return 0 if the token is not supported
        if (!_isSupported(token)) return 0;
        // Check if it is possible to send Circle tokens (it is always possible to receive them though).
        if (IPausable(synapseCCTP).paused()) return 0;
        // Get the TokenMinter contract that is used to mint Circle tokens
        address tokenMinter = ISynapseCCTP(synapseCCTP).tokenMessenger().localMinter();
        // Maximal amount of tokens that can be bridged is determined by the burn limits per message
        return ITokenMinter(tokenMinter).burnLimitsPerMessage(token);
    }

    /// @inheritdoc IBridgeModule
    function calculateFeeAmount(
        address token,
        uint256 amount,
        bool isSwap
    ) external view returns (uint256 fee) {
        // Revert if the token is not supported rather than returning 0 fee to avoid confusion
        if (!_isSupported(token)) revert SynapseCCTPModule__UnsupportedToken(token);
        return ISynapseCCTPFees(synapseCCTP).calculateFeeAmount(token, amount, isSwap);
    }

    /// @inheritdoc IBridgeModule
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens) {
        return ISynapseCCTPFees(synapseCCTP).getBridgeTokens();
    }

    /// @inheritdoc IBridgeModule
    function symbolToToken(string memory symbol) external view returns (address token) {
        return ISynapseCCTPFees(synapseCCTP).symbolToToken(symbol);
    }

    /// @inheritdoc IBridgeModule
    function tokenToSymbol(address token) external view returns (string memory symbol) {
        return ISynapseCCTPFees(synapseCCTP).tokenToSymbol(token);
    }

    /// @inheritdoc IBridgeModule
    function tokenToActionMask(address token) external view returns (uint256 actionMask) {
        // Return empty mask if the token is not supported
        if (!_isSupported(token)) return 0;
        // SynapseCCTP only supports Action.Swap
        return Action.Swap.mask();
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Checks if a token is supported by SynapseCCTP.
    function _isSupported(address token) internal view returns (bool) {
        // Token is supported if the symbol is not empty
        return bytes(ISynapseCCTPFees(synapseCCTP).tokenToSymbol(token)).length > 0;
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
        // Actions other than swap are not supported for Circle tokens on the destination chain
        if (params.action != Action.Swap) revert SynapseCCTPModule__UnsupportedAction(params.action);
        // Don't allow having the same token index for `tokenIndexFrom` and `tokenIndexTo`
        if (params.tokenIndexFrom == params.tokenIndexTo) {
            revert SynapseCCTPModule__EqualSwapIndexes(params.tokenIndexFrom);
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
