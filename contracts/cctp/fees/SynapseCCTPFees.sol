// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTPFeesEvents} from "../events/SynapseCCTPFeesEvents.sol";
import {ISynapseCCTPFees} from "../interfaces/ISynapseCCTPFees.sol";
// prettier-ignore
import {
    CCTPGasRescueFailed,
    CCTPIncorrectConfig,
    CCTPIncorrectProtocolFee,
    CCTPInsufficientAmount,
    CCTPSymbolAlreadyAdded,
    CCTPSymbolIncorrect,
    CCTPTokenAlreadyAdded,
    CCTPTokenNotFound
} from "../libs/Errors.sol";
import {TypeCasts} from "../libs/TypeCasts.sol";
import {BridgeToken} from "../../router/libs/Structs.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable-4.5.0/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts-4.5.0/utils/structs/EnumerableSet.sol";

abstract contract SynapseCCTPFees is SynapseCCTPFeesEvents, OwnableUpgradeable, ISynapseCCTPFees {
    using EnumerableSet for EnumerableSet.AddressSet;
    using TypeCasts for uint256;

    /// @notice CCTP fee structure for a supported Circle token.
    /// @dev Optimized for storage. 2**72 is 4*10**21, which is enough to represent adequate amounts
    /// for stable coins with 18 decimals. Circle tokens have 6 decimals, so this is more than enough.
    /// @param relayerFee   Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @param minBaseFee   Minimum fee for bridging a token to this chain using a base request
    /// @param minSwapFee   Minimum fee for bridging a token to this chain using a swap request
    /// @param maxFee       Maximum fee for bridging a token to this chain
    struct CCTPFee {
        uint40 relayerFee;
        uint72 minBaseFee;
        uint72 minSwapFee;
        uint72 maxFee;
    }

    /// @dev Denominator used to calculate the bridge fee
    uint256 private constant FEE_DENOMINATOR = 10**10;
    /// @dev Maximum relayer fee that can be set: 10 bps
    uint256 private constant MAX_RELAYER_FEE = 10**7;
    /// @dev Maximum protocol fee that can be set: 50%
    uint256 private constant MAX_PROTOCOL_FEE = FEE_DENOMINATOR / 2;
    /// @dev Mandatory prefix used for CCTP token symbols to distinguish them from other bridge symbols
    bytes private constant SYMBOL_PREFIX = "CCTP.";
    /// @dev Length of the mandatory prefix used for CCTP token symbols
    uint256 private constant SYMBOL_PREFIX_LENGTH = 5;

    // ══════════════════════════════════════════════════ STORAGE ══════════════════════════════════════════════════════

    /// @notice Maps bridge token address into bridge token symbol
    mapping(address => string) public tokenToSymbol;
    /// @notice Maps bridge token symbol into bridge token address
    mapping(string => address) public symbolToToken;
    /// @notice Maps bridge token address into CCTP fee structure
    mapping(address => CCTPFee) public feeStructures;
    /// @notice Maps fee collector address into accumulated fees for a token
    /// (feeCollector => (token => amount))
    /// @dev Fee collector address of address(0) indicates that fees are accumulated by the Protocol
    mapping(address => mapping(address => uint256)) public accumulatedFees;
    /// @notice Maps Relayer address into collector address for accumulated Relayer's fees
    /// @dev Default value of address(0) indicates that a Relayer's fees are accumulated by the Protocol
    mapping(address => address) public relayerFeeCollectors;
    /// @notice Protocol fee: percentage of the relayer fee that is collected by the Protocol
    /// @dev Protocol collects the full fee amount, if the Relayer hasn't set a fee collector
    uint256 public protocolFee;
    /// @notice Amount of chain's native gas airdropped to the token recipient for every fulfilled CCTP request
    uint256 public chainGasAmount;
    /// @dev A list of all supported bridge tokens
    /// Note: takes two storage slots
    EnumerableSet.AddressSet internal _bridgeTokens;

    /**
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[41] private __gap;

    // ════════════════════════════════════════════════ ONLY OWNER ═════════════════════════════════════════════════════

    /// @notice Adds a new token to the list of supported tokens, with the given symbol and fee structure.
    /// @dev The symbol must start with "CCTP."
    /// @param symbol       Symbol of the token
    /// @param token        Address of the token
    /// @param relayerFee   Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @param minBaseFee   Minimum fee for bridging a token to this chain using a base request
    /// @param minSwapFee   Minimum fee for bridging a token to this chain using a swap request
    /// @param maxFee       Maximum fee for bridging a token to this chain
    function addToken(
        string memory symbol,
        address token,
        uint256 relayerFee,
        uint256 minBaseFee,
        uint256 minSwapFee,
        uint256 maxFee
    ) external onlyOwner {
        if (token == address(0)) revert CCTPIncorrectConfig();
        // Add a new token to the list of supported tokens, and check that it hasn't been added before
        if (!_bridgeTokens.add(token)) revert CCTPTokenAlreadyAdded();
        // Check that symbol hasn't been added yet and starts with "CCTP."
        _assertCanAddSymbol(symbol);
        // Add token <> symbol link
        tokenToSymbol[token] = symbol;
        symbolToToken[symbol] = token;
        // Set token fee
        _setTokenFee(token, relayerFee, minBaseFee, minSwapFee, maxFee);
    }

    /// @notice Removes a token from the list of supported tokens.
    /// @dev Will revert if the token is not supported.
    function removeToken(address token) external onlyOwner {
        // Remove a token from the list of supported tokens, and check that it has been added before
        if (!_bridgeTokens.remove(token)) revert CCTPTokenNotFound();
        // Remove token <> symbol link
        string memory symbol = tokenToSymbol[token];
        delete tokenToSymbol[token];
        delete symbolToToken[symbol];
        // Remove token fee structure
        delete feeStructures[token];
    }

    /// @notice Allows to rescue stuck gas from the contract.
    function rescueGas() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert CCTPGasRescueFailed();
    }

    /// @notice Sets the amount of chain gas airdropped to the token recipient for every fulfilled CCTP request.
    function setChainGasAmount(uint256 newChainGasAmount) external onlyOwner {
        chainGasAmount = newChainGasAmount;
        emit ChainGasAmountUpdated(newChainGasAmount);
    }

    /// @notice Updates the fee structure for a supported Circle token.
    /// @dev Will revert if the token is not supported.
    /// @param token        Address of the token
    /// @param relayerFee   Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @param minBaseFee   Minimum fee for bridging a token to this chain using a base request
    /// @param minSwapFee   Minimum fee for bridging a token to this chain using a swap request
    /// @param maxFee       Maximum fee for bridging a token to this chain
    function setTokenFee(
        address token,
        uint256 relayerFee,
        uint256 minBaseFee,
        uint256 minSwapFee,
        uint256 maxFee
    ) external onlyOwner {
        if (!_bridgeTokens.contains(token)) revert CCTPTokenNotFound();
        _setTokenFee(token, relayerFee, minBaseFee, minSwapFee, maxFee);
    }

    /// @notice Sets a new protocol fee.
    /// @dev The protocol fee is a percentage of the relayer fee that is collected by the Protocol.
    /// @param newProtocolFee   New protocol fee, multiplied by `FEE_DENOMINATOR`
    function setProtocolFee(uint256 newProtocolFee) external onlyOwner {
        if (newProtocolFee > MAX_PROTOCOL_FEE) revert CCTPIncorrectProtocolFee();
        protocolFee = newProtocolFee;
        emit ProtocolFeeUpdated(newProtocolFee);
    }

    // ═══════════════════════════════════════════ RELAYER INTERACTIONS ════════════════════════════════════════════════

    /// @notice Allows the Relayer to set a fee collector for accumulated fees.
    /// - New fees accumulated by the Relayer could only be withdrawn by new Relayer's fee collector.
    /// - Old fees accumulated by the Relayer could only be withdrawn by old Relayer's fee collector.
    /// @dev Default value of address(0) indicates that a Relayer's fees are accumulated by the Protocol.
    function setFeeCollector(address feeCollector) external {
        address oldFeeCollector = relayerFeeCollectors[msg.sender];
        relayerFeeCollectors[msg.sender] = feeCollector;
        emit FeeCollectorUpdated(msg.sender, oldFeeCollector, feeCollector);
    }

    // ═══════════════════════════════════════════════════ VIEWS ═══════════════════════════════════════════════════════

    /// @notice Calculates the fee amount for bridging a token to this chain using CCTP.
    /// @dev Will not check if fee exceeds the token amount. Will return 0 if the token is not supported.
    /// @param token        Address of the Circle token
    /// @param amount       Amount of the Circle tokens to be bridged to this chain
    /// @param isSwap       Whether the request is a swap request
    /// @return fee         Fee amount
    function calculateFeeAmount(
        address token,
        uint256 amount,
        bool isSwap
    ) external view returns (uint256 fee) {
        return _calculateFeeAmount(token, amount, isSwap);
    }

    /// @notice Returns the list of all supported bridge tokens and their symbols.
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens) {
        uint256 length = _bridgeTokens.length();
        bridgeTokens = new BridgeToken[](length);
        for (uint256 i = 0; i < length; i++) {
            address token = _bridgeTokens.at(i);
            bridgeTokens[i] = BridgeToken({symbol: tokenToSymbol[token], token: token});
        }
    }

    // ══════════════════════════════════════════════ INTERNAL LOGIC ═══════════════════════════════════════════════════

    /// @dev Applies the relayer fee and updates the accumulated fee amount for the token.
    /// Will revert if the fee exceeds the token amount, or token is not supported.
    function _applyRelayerFee(
        address token,
        uint256 amount,
        bool isSwap
    ) internal returns (uint256 amountAfterFee, uint256 fee) {
        if (!_bridgeTokens.contains(token)) revert CCTPTokenNotFound();
        fee = _calculateFeeAmount(token, amount, isSwap);
        if (fee >= amount) revert CCTPInsufficientAmount();
        // Could use the unchecked math, as we already checked that fee < amount
        unchecked {
            amountAfterFee = amount - fee;
        }
        // Check if the Relayer has specified a fee collector
        address feeCollector = relayerFeeCollectors[msg.sender];
        if (feeCollector == address(0)) {
            // If the fee collector is not set, the Protocol will collect the full fees
            accumulatedFees[address(0)][token] += fee;
            emit FeeCollected(address(0), 0, fee);
        } else {
            // Otherwise, the Relayer and the Protocol will split the fees
            uint256 protocolFeeAmount = (fee * protocolFee) / FEE_DENOMINATOR;
            uint256 relayerFeeAmount = fee - protocolFeeAmount;
            accumulatedFees[address(0)][token] += protocolFeeAmount;
            accumulatedFees[feeCollector][token] += relayerFeeAmount;
            emit FeeCollected(feeCollector, relayerFeeAmount, protocolFeeAmount);
        }
    }

    /// @dev Sets the fee structure for a supported Circle token.
    function _setTokenFee(
        address token,
        uint256 relayerFee,
        uint256 minBaseFee,
        uint256 minSwapFee,
        uint256 maxFee
    ) internal {
        // Check that relayer fee is not too high
        if (relayerFee > MAX_RELAYER_FEE) revert CCTPIncorrectConfig();
        // Min base fee must not exceed min swap fee
        if (minBaseFee > minSwapFee) revert CCTPIncorrectConfig();
        // Min swap fee must not exceed max fee
        if (minSwapFee > maxFee) revert CCTPIncorrectConfig();
        feeStructures[token] = CCTPFee({
            relayerFee: relayerFee.safeCastToUint40(),
            minBaseFee: minBaseFee.safeCastToUint72(),
            minSwapFee: minSwapFee.safeCastToUint72(),
            maxFee: maxFee.safeCastToUint72()
        });
    }

    /// @dev Transfers `msg.value` to the recipient. Assumes that `msg.value == chainGasAmount` at this point.
    function _transferMsgValue(address recipient) internal {
        // Try to send the gas airdrop to the recipient
        (bool success, ) = recipient.call{value: msg.value}("");
        // If the transfer failed, set the emitted amount to 0
        emit ChainGasAirdropped(success ? msg.value : 0);
    }

    // ══════════════════════════════════════════════ INTERNAL VIEWS ═══════════════════════════════════════════════════

    /// @dev Checks that the symbol hasn't been added yet and starts with "CCTP."
    function _assertCanAddSymbol(string memory symbol) internal view {
        // Check if the symbol has already been added
        if (symbolToToken[symbol] != address(0)) revert CCTPSymbolAlreadyAdded();
        // Cast to bytes to check the length
        bytes memory symbolBytes = bytes(symbol);
        // Check that symbol is correct: starts with "CCTP." and has at least 1 more character
        if (symbolBytes.length <= SYMBOL_PREFIX_LENGTH) revert CCTPSymbolIncorrect();
        for (uint256 i = 0; i < SYMBOL_PREFIX_LENGTH; ) {
            if (symbolBytes[i] != SYMBOL_PREFIX[i]) revert CCTPSymbolIncorrect();
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Calculates the fee amount for bridging a token to this chain using CCTP.
    /// Will not check if fee exceeds the token amount. Will return 0 if the token is not supported.
    function _calculateFeeAmount(
        address token,
        uint256 amount,
        bool isSwap
    ) internal view returns (uint256 fee) {
        CCTPFee memory feeStructure = feeStructures[token];
        // Calculate the fee amount
        fee = (amount * feeStructure.relayerFee) / FEE_DENOMINATOR;
        // Apply minimum fee
        uint256 minFee = isSwap ? feeStructure.minSwapFee : feeStructure.minBaseFee;
        if (fee < minFee) fee = minFee;
        // Apply maximum fee
        if (fee > feeStructure.maxFee) fee = feeStructure.maxFee;
    }
}
