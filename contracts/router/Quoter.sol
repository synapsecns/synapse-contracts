// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BasicQuoter} from "./BasicQuoter.sol";

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {Offers} from "./libraries/LibOffers.sol";

import {Bytes} from "@synapseprotocol/sol-lib/contracts/universal/lib/LibBytes.sol";

contract Quoter is BasicQuoter, IQuoter {
    /// @dev Setup flow:
    /// 1. Create Router contract
    /// 2. Create Quoter contract
    /// 3. Give Quoter ADAPTERS_STORAGE_ROLE in Router contract
    /// 4. Add tokens and adapters

    /// PS. If the migration from one Quoter to another is needed (w/0 changing Router):
    /// 1. call oldQuoter.setAdapters([]), this will clear the adapters in Router
    /// 2. revoke ADAPTERS_STORAGE_ROLE from oldQuoter
    /// 3. Do (2-4) from setup flow as usual
    constructor(address payable _router, uint8 _maxSwaps)
        BasicQuoter(_router, _maxSwaps)
    {
        this;
    }

    // -- FIND BEST PATH --

    /**
        @notice Find the best path between two tokens

        @param amountIn amount of initial tokens to swap
        @param tokenIn initial token to sell
        @param tokenOut final token to buy
        @param maxSwaps maximum amount of swaps in the route between initial and final tokens
    */
    function findBestPath(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint8 maxSwaps
    ) public view returns (Offers.FormattedOffer memory _bestOffer) {
        require(
            maxSwaps > 0 && maxSwaps <= MAX_SWAPS,
            "Quoter: Invalid max-swaps"
        );
        Offers.Offer memory queries;
        queries.amounts = Bytes.toBytes(amountIn);
        queries.path = Bytes.toBytes(tokenIn);

        queries = _findBestPath(amountIn, tokenIn, tokenOut, maxSwaps, queries);

        // If no paths are found, return empty struct
        if (queries.adapters.length == 0) {
            queries.amounts = "";
            queries.path = "";
        }
        return Offers.formatOfferWithGas(queries);
    }

    /**
        @notice Find the best path between two tokens, using the predefined
                maximum amount of swaps in the route between initial and final tokens
        @param amountIn amount of initial tokens to swap
        @param tokenIn initial token to sell
        @param tokenOut final token to buy
    */
    function findBestPathMaxSwaps(
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) external view returns (Offers.FormattedOffer memory _bestOffer) {
        // User pays for gas, so:
        // use maximum swaps permitted for the search
        _bestOffer = findBestPath(tokenIn, amountIn, tokenOut, MAX_SWAPS);
    }

    // -- INTERNAL HELPERS

    /**
        @notice Find the best path between two tokens
        @dev Part of the route is fixed, which is reflected in queries
             The return value is unformatted byte arrays, use Offers.formatOfferWithGas() to format

        @param amountIn amount of current tokens to swap
        @param tokenIn current token to sell
        @param tokenOut final token to buy
        @param maxSwaps maximum amount of swaps in the route between initial and final tokens
        @param queries Fixed prefix of the route between initial and final tokens
        @return bestOption bytes amounts, bytes adapters, bytes path
     */
    function _findBestPath(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 maxSwaps,
        Offers.Offer memory queries
    ) internal view returns (Offers.Offer memory) {
        Offers.Offer memory bestOption = Offers.cloneOfferWithGas(queries);
        /// @dev bestAmountOut is net returns of the swap,
        /// this is the parameter that should be maximized

        // bestAmountOut: amount of tokenOut in the local best found route

        // First check if there is a path directly from tokenIn to tokenOut
        uint256 bestAmountOut = _checkDirectSwap(
            amountIn,
            tokenIn,
            tokenOut,
            bestOption
        );

        // Check for swaps through intermediate tokens, only if there are enough swaps left
        // Need at least two extra swaps
        if (maxSwaps > 1 && queries.adapters.length / 32 <= maxSwaps - 2) {
            // Check for paths that pass through trusted tokens
            for (uint256 i = 0; i < trustedTokens.length; i++) {
                address trustedToken = trustedTokens[i];
                // ignore tokens already present in path
                if (Offers.containsToken(queries.path, trustedToken)) {
                    continue;
                }
                // trustedToken == tokenOut was checked above in _checkDirectSwap
                if (trustedToken == tokenOut) {
                    continue;
                }
                // Loop through all adapters to find the best one
                // for swapping tokenIn for one of the trusted tokens

                Query memory bestSwap = queryDirectSwap(
                    amountIn,
                    tokenIn,
                    trustedToken
                );
                if (bestSwap.amountOut == 0) {
                    continue;
                }
                Offers.Offer memory newOffer = Offers.cloneOfferWithGas(
                    queries
                );
                // add bestSwap to the current route
                Offers.addQuery(
                    newOffer,
                    bestSwap.amountOut,
                    bestSwap.adapter,
                    bestSwap.tokenOut
                );
                // Find best path, starting with current route + bestSwap
                // new current token is trustedToken
                // its amount is bestSwap.amountOut
                newOffer = _findBestPath(
                    bestSwap.amountOut,
                    trustedToken,
                    tokenOut,
                    maxSwaps,
                    newOffer
                );
                address lastToken = Bytes.toAddress(
                    newOffer.path.length,
                    newOffer.path
                );
                // Check that the last token in the path is tokenOut and update the new best option
                // only if amountOut is increased
                if (lastToken == tokenOut) {
                    uint256 newAmountOut = Bytes.toUint256(
                        newOffer.amounts.length,
                        newOffer.amounts
                    );

                    // bestAmountOut == 0 means we don't have the "best" option yet
                    if (bestAmountOut < newAmountOut || bestAmountOut == 0) {
                        bestAmountOut = newAmountOut;
                        bestOption = newOffer;
                    }
                }
            }
        }
        return bestOption;
    }

    /**
        @notice Get the best swap quote using any of the adapters
        @param amountIn amount of tokens to swap
        @param tokenIn token to sell
        @param tokenOut token to buy
        @return bestQuery Query with best quote available
     */
    function queryDirectSwap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view returns (Query memory bestQuery) {
        for (uint8 i = 0; i < trustedAdapters.length; ++i) {
            address adapter = trustedAdapters[i];
            uint256 amountOut = IAdapter(adapter).query(
                amountIn,
                tokenIn,
                tokenOut
            );
            if (amountOut == 0) {
                continue;
            }

            // bestQuery.amountOut == 0 means there's no "best" yet
            if (amountOut > bestQuery.amountOut || bestQuery.amountOut == 0) {
                bestQuery = Query(adapter, tokenIn, tokenOut, amountOut);
            }
        }
    }

    /**
        @notice Find the best direct swap between tokens and append it to current Offer
        @dev Nothing will be appended, if no direct route between tokens is found
        @param amountIn amount of initial token to swap
        @param tokenIn current token to sell
        @param tokenOut final token to buy
        @param bestOption current Offer to append the found swap
     */
    function _checkDirectSwap(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        Offers.Offer memory bestOption
    ) internal view returns (uint256 amountOut) {
        Query memory queryDirect = queryDirectSwap(amountIn, tokenIn, tokenOut);
        if (queryDirect.amountOut != 0) {
            Offers.addQuery(
                bestOption,
                queryDirect.amountOut,
                queryDirect.adapter,
                queryDirect.tokenOut
            );
            amountOut = queryDirect.amountOut;
        }
    }
}
