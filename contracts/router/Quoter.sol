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

        @param _amountIn amount of initial tokens to swap
        @param _tokenIn initial token to sell
        @param _tokenOut final token to buy
        @param _maxSwaps maximum amount of swaps in the route between initial and final tokens
    */
    function findBestPath(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps
    ) public view returns (Offers.FormattedOffer memory _bestOffer) {
        require(
            _maxSwaps > 0 && _maxSwaps <= maxSwaps,
            "Quoter: Invalid max-swaps"
        );
        Offers.Offer memory _queries;
        _queries.amounts = Bytes.toBytes(_amountIn);
        _queries.path = Bytes.toBytes(_tokenIn);

        _queries = _findBestPath(
            _amountIn,
            _tokenIn,
            _tokenOut,
            _maxSwaps,
            _queries
        );

        // If no paths are found, return empty struct
        if (_queries.adapters.length == 0) {
            _queries.amounts = "";
            _queries.path = "";
        }
        return Offers.formatOfferWithGas(_queries);
    }

    // -- INTERNAL HELPERS

    /**
        @notice Find the best path between two tokens
        @dev Part of the route is fixed, which is reflected in _queries
             The return value is unformatted byte arrays, use Offers.formatOfferWithGas() to format

        @param _amountIn amount of current tokens to swap
        @param _tokenIn current token to sell
        @param _tokenOut final token to buy
        @param _maxSwaps maximum amount of swaps in the route between initial and final tokens
        @param _queries Fixed prefix of the route between initial and final tokens
        @return _bestOption bytes amounts, bytes adapters, bytes path
     */
    function _findBestPath(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSwaps,
        Offers.Offer memory _queries
    ) internal view returns (Offers.Offer memory) {
        Offers.Offer memory _bestOption = Offers.cloneOfferWithGas(_queries);
        /// @dev _bestAmountOut is net returns of the swap,
        /// this is the parameter that should be maximized

        // _bestAmountOut: amount of _tokenOut in the local best found route

        // First check if there is a path directly from tokenIn to tokenOut
        uint256 _bestAmountOut = _checkDirectSwap(
            _amountIn,
            _tokenIn,
            _tokenOut,
            _bestOption
        );

        // Check for swaps through intermediate tokens, only if there are enough swaps left
        // Need at least two extra swaps
        if (_maxSwaps > 1 && _queries.adapters.length / 32 <= _maxSwaps - 2) {
            // Check for paths that pass through trusted tokens
            for (uint256 i = 0; i < trustedTokens.length; i++) {
                address _trustedToken = trustedTokens[i];
                // _trustedToken == _tokenIn  means swap isn't possible
                // _trustedToken == _tokenOut was checked above in _checkDirectSwap
                if (_trustedToken == _tokenIn || _trustedToken == _tokenOut) {
                    continue;
                }
                // Loop through all adapters to find the best one
                // for swapping tokenIn for one of the trusted tokens

                Query memory _bestSwap = _queryDirectSwap(
                    _amountIn,
                    _tokenIn,
                    _trustedToken
                );
                if (_bestSwap.amountOut == 0) {
                    continue;
                }
                Offers.Offer memory newOffer = Offers.cloneOfferWithGas(
                    _queries
                );
                // add _bestSwap to the current route
                Offers.addQuery(
                    newOffer,
                    _bestSwap.amountOut,
                    _bestSwap.adapter,
                    _bestSwap.tokenOut
                );
                // Find best path, starting with current route + _bestSwap
                // new current token is _trustedToken
                // its amount is _bestSwap.amountOut
                newOffer = _findBestPath(
                    _bestSwap.amountOut,
                    _trustedToken,
                    _tokenOut,
                    _maxSwaps,
                    newOffer
                );
                address tokenOut = Bytes.toAddress(
                    newOffer.path.length,
                    newOffer.path
                );
                // Check that the last token in the path is tokenOut and update the new best option
                // only if amountOut is increased
                if (_tokenOut == tokenOut) {
                    uint256 newAmountOut = Bytes.toUint256(
                        newOffer.amounts.length,
                        newOffer.amounts
                    );

                    // bestAmountOut == 0 means we don't have the "best" option yet
                    if (_bestAmountOut < newAmountOut || _bestAmountOut == 0) {
                        _bestAmountOut = newAmountOut;
                        _bestOption = newOffer;
                    }
                }
            }
        }
        return _bestOption;
    }

    /**
        @notice Get the best swap quote using any of the adapters
        @param _amountIn amount of tokens to swap
        @param _tokenIn token to sell
        @param _tokenOut token to buy
        @return _bestQuery Query with best quote available
     */
    function _queryDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view returns (Query memory _bestQuery) {
        for (uint8 i = 0; i < trustedAdapters.length; ++i) {
            address _adapter = trustedAdapters[i];
            uint256 amountOut = IAdapter(_adapter).query(
                _amountIn,
                _tokenIn,
                _tokenOut
            );
            if (amountOut == 0) {
                continue;
            }

            // _bestQuery.amountOut == 0 means there's no "best" yet
            if (amountOut > _bestQuery.amountOut || _bestQuery.amountOut == 0) {
                _bestQuery = Query(_adapter, _tokenIn, _tokenOut, amountOut);
            }
        }
    }

    /**
        @notice Find the best direct swap between tokens and append it to current Offer
        @dev Nothing will be appended, if no direct route between tokens is found
        @param _amountIn amount of initial token to swap
        @param _tokenIn current token to sell
        @param _tokenOut final token to buy
        @param _bestOption current Offer to append the found swap
     */
    function _checkDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        Offers.Offer memory _bestOption
    ) internal view returns (uint256 _amountOut) {
        Query memory _queryDirect = _queryDirectSwap(
            _amountIn,
            _tokenIn,
            _tokenOut
        );
        if (_queryDirect.amountOut != 0) {
            Offers.addQuery(
                _bestOption,
                _queryDirect.amountOut,
                _queryDirect.adapter,
                _queryDirect.tokenOut
            );
            _amountOut = _queryDirect.amountOut;
        }
    }
}
