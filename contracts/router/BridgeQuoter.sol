// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Quoter} from "./Quoter.sol";

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";
import {IBridgeQuoter} from "./interfaces/IBridgeQuoter.sol";
import {IBridge} from "../vault/interfaces/IBridge.sol";
import {IBridgeConfig} from "../vault/interfaces/IBridgeConfig.sol";

import {Offers} from "./libraries/LibOffers.sol";

contract BridgeQuoter is Quoter, IBridgeQuoter {
    IBridgeConfig public immutable bridgeConfig;

    /// @dev Setup flow:
    /// 1. Create BridgeRouter contract
    /// 2. Create BridgeQuoter contract
    /// 3. Give BridgeQuoter ADAPTERS_STORAGE_ROLE in BridgeRouter contract
    /// 4. Add tokens and adapters

    /// PS. If the migration from one BridgeQuoter to another is needed (w/0 changing BridgeRouter):
    /// 1. call oldBridgeQuoter.setAdapters([]), this will clear the adapters in BridgeRouter
    /// 2. revoke ADAPTERS_STORAGE_ROLE from oldBridgeQuoter
    /// 3. Do (2-4) from setup flow as usual
    constructor(address payable _router, uint8 _maxSwaps) Quoter(_router, _maxSwaps) {
        bridgeConfig = IBridge(IBridgeRouter(_router).bridge()).bridgeConfig();
    }

    // -- BEST PATH: source chain --

    function bestPathToBridge(
        address tokenIn,
        uint256 amountIn,
        address bridgeTokenSrc
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        bestOffer = _findBestPathSrc(tokenIn, amountIn, bridgeTokenSrc);
    }

    function bestPathToBridgeEVM(
        address tokenIn,
        uint256 amountIn,
        uint256 chainId,
        address bridgeTokenDst
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        address bridgeTokenSrc = bridgeConfig.findTokenEVM(chainId, bridgeTokenDst);
        if (bridgeTokenSrc != address(0)) {
            bestOffer = _findBestPathSrc(tokenIn, amountIn, bridgeTokenSrc);
        }
    }

    function bestPathToBridgeNonEVM(
        address tokenIn,
        uint256 amountIn,
        uint256 chainId,
        string calldata bridgeTokenDst
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        address bridgeTokenSrc = bridgeConfig.findTokenNonEVM(chainId, bridgeTokenDst);
        if (bridgeTokenSrc != address(0)) {
            bestOffer = _findBestPathSrc(tokenIn, amountIn, bridgeTokenSrc);
        }
    }

    function _findBestPathSrc(
        address tokenIn,
        uint256 amountIn,
        address bridgeTokenSrc
    ) internal view returns (Offers.FormattedOffer memory bestOffer) {
        if (bridgeConfig.isTokenEnabled(bridgeTokenSrc)) {
            bestOffer = findBestPath(tokenIn, amountIn, bridgeTokenSrc, MAX_SWAPS);
        }
    }

    // -- BEST PATH: destination chain --

    function bestPathFromBridge(
        address bridgeTokenDst,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        bestOffer = _findBestPathDst(bridgeTokenDst, amountIn, tokenOut, gasdropRequested);
    }

    function bestPathFromBridgeEVM(
        uint256 chainId,
        address bridgeTokenSrc,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        address bridgeTokenDst = bridgeConfig.findTokenEVM(chainId, bridgeTokenSrc);
        bestOffer = _findBestPathDst(bridgeTokenDst, amountIn, tokenOut, gasdropRequested);
    }

    function bestPathFromBridgeNonEVM(
        uint256 chainId,
        string calldata bridgeTokenSrc,
        uint256 amountIn
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        address bridgeTokenDst = bridgeConfig.findTokenNonEVM(chainId, bridgeTokenSrc);
        // Default setting for bridging from non-EVM is no swap, GasDrop enabled
        bestOffer = _findBestPathDst(bridgeTokenDst, amountIn, bridgeTokenDst, true);
    }

    function bestPathFromBridgeNonEVM(
        uint256 chainId,
        string calldata bridgeTokenSrc,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        address bridgeTokenDst = bridgeConfig.findTokenNonEVM(chainId, bridgeTokenSrc);

        bestOffer = _findBestPathDst(bridgeTokenDst, amountIn, tokenOut, gasdropRequested);
    }

    function _findBestPathDst(
        address bridgeTokenDst,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) internal view returns (Offers.FormattedOffer memory bestOffer) {
        bool swapRequested = bridgeTokenDst != tokenOut;
        uint8 amountOfSwaps = IBridgeRouter(router).bridgeMaxSwaps();
        (uint256 fee, , bool isEnabled, ) = bridgeConfig.calculateBridgeFee(
            bridgeTokenDst,
            amountIn,
            gasdropRequested,
            swapRequested ? amountOfSwaps : 0
        );

        if (isEnabled && amountIn > fee) {
            amountIn = amountIn - fee;

            if (swapRequested) {
                // Node group pays for gas, so:
                // use maximum swaps permitted for bridge+swap transaction
                bestOffer = findBestPath(bridgeTokenDst, amountIn, tokenOut, amountOfSwaps);
            } else {
                bestOffer.path = new address[](1);
                bestOffer.path[0] = bridgeTokenDst;

                bestOffer.amounts = new uint256[](1);
                bestOffer.amounts[0] = amountIn;

                // bestOffer.adapters is empty
            }
        }
    }

    /// @dev Mirror functions from BridgeConfig, so that UI can only interact with BridgeQuoter

    function getAllBridgeTokensEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, address[] memory tokensGlobal)
    {
        return bridgeConfig.getAllBridgeTokensEVM(chainTo);
    }

    function getAllBridgeTokensNonEVM(uint256 chainTo)
        external
        view
        returns (address[] memory tokensLocal, string[] memory tokensGlobal)
    {
        return bridgeConfig.getAllBridgeTokensNonEVM(chainTo);
    }

    function getTokenAddressEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (address tokenGlobal, bool isEnabled)
    {
        return bridgeConfig.getTokenAddressEVM(tokenLocal, chainId);
    }

    function getTokenAddressNonEVM(address tokenLocal, uint256 chainId)
        external
        view
        returns (string memory tokenGlobal, bool isEnabled)
    {
        return bridgeConfig.getTokenAddressNonEVM(tokenLocal, chainId);
    }
}
