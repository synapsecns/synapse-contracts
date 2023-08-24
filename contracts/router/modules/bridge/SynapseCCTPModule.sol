// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OnlyDelegateCall} from "../pool/OnlyDelegateCall.sol";
import {IBridgeModule} from "../../interfaces/IBridgeModule.sol";
import {BridgeToken, SwapQuery} from "../../libs/Structs.sol";

import {ISynapseCCTP} from "../../../cctp/interfaces/ISynapseCCTP.sol";
import {ISynapseCCTPFees} from "../../../cctp/interfaces/ISynapseCCTPFees.sol";

contract SynapseCCTPModule is OnlyDelegateCall, IBridgeModule {
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
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @inheritdoc IBridgeModule
    function getMaxBridgedAmount(address token) external view returns (uint256 amount) {}

    /// @inheritdoc IBridgeModule
    function calculateFeeAmount(
        address token,
        uint256 amount,
        bool isSwap
    ) external view returns (uint256 fee) {}

    /// @inheritdoc IBridgeModule
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens) {}

    /// @inheritdoc IBridgeModule
    function symbolToToken(string memory symbol) external view returns (address token) {}

    /// @inheritdoc IBridgeModule
    function tokenToSymbol(address token) external view returns (string memory symbol) {}

    /// @inheritdoc IBridgeModule
    function tokenToActionMask(address token) external view returns (uint256 actionMask) {}
}
