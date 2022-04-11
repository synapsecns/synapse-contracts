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
    constructor(address payable _router, uint8 _maxSwaps)
        Quoter(_router, _maxSwaps)
    {
        bridgeConfig = IBridge(IBridgeRouter(_router).bridge()).bridgeConfig();
    }

    function findBestPathInitialChain(
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        // User pays for gas, so:
        // use maximum swaps permitted for the search
        return findBestPath(tokenIn, amountIn, tokenOut, MAX_SWAPS);
    }

    function findBestPathDestinationChain(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        bool gasdropRequested
    ) external view returns (Offers.FormattedOffer memory bestOffer) {
        bool swapRequested = tokenIn != tokenOut;
        uint256 amountOfSwaps = IBridgeRouter(router).bridgeMaxSwaps();
        (uint256 fee, , bool isEnabled, ) = bridgeConfig.calculateBridgeFee(
            tokenIn,
            amountIn,
            gasdropRequested,
            swapRequested ? amountOfSwaps : 0
        );

        if (isEnabled && amountIn > fee) {
            amountIn = amountIn - fee;

            if (swapRequested) {
                // Node group pays for gas, so:
                // use maximum swaps permitted for bridge+swap transaction
                bestOffer = findBestPath(
                    tokenIn,
                    amountIn,
                    tokenOut,
                    IBridgeRouter(router).bridgeMaxSwaps()
                );
            } else {
                bestOffer.path = new address[](1);
                bestOffer.path[0] = tokenIn;

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
