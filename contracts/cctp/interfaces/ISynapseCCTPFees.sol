// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BridgeToken} from "../../router/libs/Structs.sol";

interface ISynapseCCTPFees {
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
    ) external view returns (uint256 fee);

    /// @notice Gets the fee structure for bridging a token to this chain.
    /// @dev Will return 0 for all fields if the token is not supported.
    /// @param token        Address of the Circle token
    /// @return relayerFee  Fee % for bridging a token to this chain, multiplied by `FEE_DENOMINATOR`
    /// @return minBaseFee  Minimum fee for bridging a token to this chain using a base request
    /// @return minSwapFee  Minimum fee for bridging a token to this chain using a swap request
    /// @return maxFee      Maximum fee for bridging a token to this chain
    function feeStructures(address token)
        external
        view
        returns (
            uint40 relayerFee,
            uint72 minBaseFee,
            uint72 minSwapFee,
            uint72 maxFee
        );

    /// @notice Returns the list of all supported bridge tokens and their symbols.
    function getBridgeTokens() external view returns (BridgeToken[] memory bridgeTokens);

    /// @notice Returns the address of the CCTP token for a given symbol.
    /// @dev Will return address(0) if the token is not supported.
    function symbolToToken(string memory symbol) external view returns (address token);

    /// @notice Returns the symbol of a given CCTP token.
    /// @dev Will return empty string if the token is not supported.
    function tokenToSymbol(address token) external view returns (string memory symbol);
}
