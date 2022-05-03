// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQuoter} from "./IQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IBridgeQuoter is IQuoter {
    // -- BEST PATH: initial chain --

    function bestPathToBridge(
        address tokenIn,
        uint256 amountIn,
        address bridgeToken
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function bestPathToBridgeEVM(
        address tokenIn,
        uint256 amountIn,
        uint256 chainId,
        address bridgeTokenGlobal
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function bestPathToBridgeNonEVM(
        address tokenIn,
        uint256 amountIn,
        uint256 chainId,
        string calldata bridgeTokenGlobal
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    // -- BEST PATH: destination chain --

    function bestPathFromBridge(
        address bridgeToken,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function bestPathFromBridgeEVM(
        uint256 chainId,
        address bridgeTokenGlobal,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function bestPathFromBridgeNonEVM(
        uint256 chainIdFrom,
        string calldata bridgeTokenFrom,
        uint256 amountIn
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    function bestPathFromBridgeNonEVM(
        uint256 chainIdFrom,
        string calldata bridgeTokenFrom,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer);

    // -- BRIDGE CONFIG VIEWS --

    function getAllBridgeTokensEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, address[] memory tokensGlobal);

    function getAllBridgeTokensNonEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, string[] memory tokensGlobal);

    function getTokenAddressEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (address tokenGlobal, bool isEnabled);

    function getTokenAddressNonEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (string memory tokenGlobal, bool isEnabled);
}
