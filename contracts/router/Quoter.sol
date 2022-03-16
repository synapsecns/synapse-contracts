// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BasicQuoter} from "./BasicQuoter.sol";

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IQuoter} from "./interfaces/IQuoter.sol";
import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {Offers} from "./libraries/LibOffers.sol";

import {Bytes} from "@synapseprotocol/sol-lib/contracts/universal/lib/LibBytes.sol";

contract Quoter is BasicQuoter, IQuoter {
    /// @dev This is address of contract representing
    /// wrapped ERC20 version of a chain's native currency (ex. WETH, WAVAX, WMOVR)
    // solhint-disable-next-line
    address payable public immutable WGAS;

    uint256 internal constant SLIPPAGE_PRECISION = 10**18;

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
        WGAS = IBasicRouter(_router).WGAS();
    }

    // -- DIRECT SWAP QUERIES --

    /**
        @notice Get the best swap quote using any of the adapters
        @param _amountIn amount of tokens to swap
        @param _tokenIn token to sell
        @param _tokenOut token to buy
        @return _bestQuery Query with best quote available
     */
    function queryDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) public view returns (Query memory _bestQuery) {
        for (uint8 i = 0; i < trustedAdapters.length; ++i) {
            address _adapter = trustedAdapters[i];
            uint256 amountOut = IAdapter(_adapter).query(
                _amountIn,
                _tokenIn,
                _tokenOut
            );
            if (i == 0 || amountOut > _bestQuery.amountOut) {
                _bestQuery = Query(_adapter, _tokenIn, _tokenOut, amountOut);
            }
        }
    }

    // -- FIND BEST PATH --

    /**
        @notice Find the best path between two tokens, taking the gas cost into account
        @dev set _gasPrice=0 to ignore gas cost

        @param _amountIn amount of initial tokens to swap
        @param _tokenIn initial token to sell
        @param _tokenOut final token to buy
        @param _maxSwaps maximum amount of swaps in the route between initial and final tokens
        @param _gasPrice chain's current gas price, in wei
     */
    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps,
        uint256 _gasPrice
    ) public view returns (Offers.FormattedOfferWithGas memory _bestOffer) {
        require(
            _maxSwaps > 0 && _maxSwaps <= maxSwaps,
            "Quoter: Invalid max-swaps"
        );
        Offers.OfferWithGas memory _queries;
        _queries.amounts = Bytes.toBytes(_amountIn);
        _queries.path = Bytes.toBytes(_tokenIn);
        uint256 _tokenOutPriceNwei = _findTokenPriceNwei(_tokenOut, _gasPrice);

        _queries = _findBestPathWithGas(
            _amountIn,
            _tokenIn,
            _tokenOut,
            _maxSwaps,
            _queries,
            _tokenOutPriceNwei
        );

        // If no paths are found, return empty struct
        if (_queries.adapters.length == 0) {
            _queries.amounts = "";
            _queries.path = "";
        }
        return Offers.formatOfferWithGas(_queries);
    }

    /**
        @notice Find best path and get full trade data for that swap on this chain via Router
        @dev Use trade data for Router.swap|swapFromGas|swapToGas(...tradeData, to) or BridgeRouter.swapAndBridge(...tradeData, bridgeData)
        @param _amountIn amount of initial tokens
        @param _tokenIn initial token to sell
        @param _tokenOut final token to buy
        @param _maxSwaps maximum amount of swaps in the route between initial and final tokens
        @param _gasPrice this chain's current gas price, in wei
        @param _maxSwapSlippage maximum slippage user is willing to accept for swap on this chain
        @return tradeData (amountIn, minAmountOut, path, adapters)
        @return amountOut expected amount of final tokens user is going to receive on this chain 
     */
    function getTradeDataAmountOut(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps,
        uint256 _gasPrice,
        uint256 _maxSwapSlippage
    ) external view returns (Trade memory, uint256) {
        (
            Offers.FormattedOfferWithGas memory _bestOffer,
            uint256 _minAmountOut,
            uint256 _amountOut
        ) = _getBestOfferWithSlippage(
            _amountIn,
            _tokenIn,
            _tokenOut,
            _maxSwaps,
            _gasPrice,
            _maxSwapSlippage
        );

        return (
            Trade(
                _amountIn,
                _minAmountOut,
                _bestOffer.path,
                _bestOffer.adapters
            ),
            _amountOut
        );
    }

    function _getBestOfferWithSlippage(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps,
        uint256 _gasPrice,
        uint256 _maxSwapSlippage
    )
        internal
        view
        returns (
            Offers.FormattedOfferWithGas memory,
            uint256,
            uint256
        )
    {
        require(
            _maxSwapSlippage < SLIPPAGE_PRECISION,
            "Slippage can't be over 100%"
        );
        Offers.FormattedOfferWithGas memory _bestOffer = findBestPathWithGas(
            _amountIn,
            _tokenIn,
            _tokenOut,
            _maxSwaps,
            _gasPrice
        );
        // fetch _amountOut
        uint256 _amountOut = _bestOffer.amounts[_bestOffer.amounts.length - 1];
        // apply slippage
        uint256 _minAmountOut = (_amountOut *
            (SLIPPAGE_PRECISION - _maxSwapSlippage)) / SLIPPAGE_PRECISION;

        return (_bestOffer, _minAmountOut, _amountOut);
    }

    // -- INTERNAL HELPERS

    /**
        @notice Express gas price in _token currency, as if _token was the chain's native token
        @dev Result is in nanoWei to preserve digits for tokens with low amount of decimals (i.e. USDC)

        @param _token token to express gas price in
        @param _gasPrice chain's current gas price, in wei
     */
    function _findTokenPriceNwei(address _token, uint256 _gasPrice)
        internal
        view
        returns (uint256)
    {
        if (_gasPrice == 0) {
            return 0;
        }

        if (_token == WGAS) {
            // Good news, everyone! _token is indeed chain's native token
            // nothing needs to be done except for conversion to nanoWei
            return _gasPrice * 1e9;
        } else {
            Offers.OfferWithGas memory gasQueries;
            gasQueries.amounts = Bytes.toBytes(1e18);
            gasQueries.path = Bytes.toBytes(WGAS);
            Offers.OfferWithGas memory gasQuery = _findBestPathWithGas(
                1e18, // find how much 1 WGAS is worth in _token
                WGAS,
                _token,
                2, // limit amount of swaps to 2
                gasQueries,
                0 // ignore gas costs
            );
            uint256[] memory _tokenOutAmounts = Offers.formatAmounts(
                gasQuery.amounts
            );
            // convert to nanoWei
            return
                (_tokenOutAmounts[_tokenOutAmounts.length - 1] * _gasPrice) /
                1e9;
        }
    }

    /**
        @notice Find the best path between two tokens, taking the gas cost into account
        @dev Part of the route is fixed, which is reflected in _queries

        @param _amountIn amount of current tokens to swap
        @param _tokenIn current token to sell
        @param _tokenOut final token to buy
        @param _maxSwaps maximum amount of swaps in the route between initial and final tokens
        @param _queries Fixed prefix of the route between initial and final tokens
        @param _tokenOutPriceNwei gas price expressed in _tokenOut, in nanoWei
     */
    function _findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSwaps,
        Offers.OfferWithGas memory _queries,
        uint256 _tokenOutPriceNwei
    ) internal view returns (Offers.OfferWithGas memory) {
        Offers.OfferWithGas memory _bestOption = Offers.cloneOfferWithGas(
            _queries
        );
        /// @dev (_bestAmountOut - _bestGasCost) is net returns of the swap,
        /// this is the parameter that should be maximized

        // _bestAmountOut: amount of _tokenOut in the local best found route
        // _bestGasCost: gas cost of the local best found route (in _tokenOut)

        // First check if there is a path directly from tokenIn to tokenOut
        (uint256 _bestAmountOut, uint256 _bestGasCost) = _checkDirectSwap(
            _amountIn,
            _tokenIn,
            _tokenOut,
            _bestOption,
            _tokenOutPriceNwei
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
                Query memory _bestSwap = queryDirectSwap(
                    _amountIn,
                    _tokenIn,
                    _trustedToken
                );
                if (_bestSwap.amountOut == 0) {
                    continue;
                }
                Offers.OfferWithGas memory newOffer = Offers.cloneOfferWithGas(
                    _queries
                );
                // add _bestSwap to the current route
                Offers.addQueryWithGas(
                    newOffer,
                    _bestSwap.amountOut,
                    _bestSwap.adapter,
                    _bestSwap.tokenOut,
                    _getGasEstimate(_bestSwap.adapter, _tokenOutPriceNwei)
                );
                // Find best path, starting with current route + _bestSwap
                // new current token is _trustedToken
                // its amount is _bestSwap.amountOut
                newOffer = _findBestPathWithGas(
                    _bestSwap.amountOut,
                    _trustedToken,
                    _tokenOut,
                    _maxSwaps,
                    newOffer,
                    _tokenOutPriceNwei
                );
                address tokenOut = Bytes.toAddress(
                    newOffer.path.length,
                    newOffer.path
                );
                // Check that the last token in the path is tokenOut and update the new best option
                // only if (amountOut - gasCost) is increased
                if (_tokenOut == tokenOut) {
                    uint256 newAmountOut = Bytes.toUint256(
                        newOffer.amounts.length,
                        newOffer.amounts
                    );
                    uint256 newGasCost = _getGasCost(
                        _tokenOutPriceNwei,
                        newOffer.gasEstimate
                    );
                    // To avoid overflow, we use the safe equivalent of
                    // (bestAmountOut - bestGasCost < newAmountOut - newGasCost)
                    if (
                        _bestAmountOut + newGasCost <
                        newAmountOut + _bestGasCost
                    ) {
                        _bestAmountOut = newAmountOut;
                        _bestGasCost = newGasCost;
                        _bestOption = newOffer;
                    }
                }
            }
        }
        return _bestOption;
    }

    function _checkDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        Offers.OfferWithGas memory _bestOption,
        uint256 _tokenOutPriceNwei
    ) internal view returns (uint256 _amountOut, uint256 _gasCost) {
        Query memory _queryDirect = queryDirectSwap(
            _amountIn,
            _tokenIn,
            _tokenOut
        );
        if (_queryDirect.amountOut != 0) {
            Offers.addQueryWithGas(
                _bestOption,
                _queryDirect.amountOut,
                _queryDirect.adapter,
                _queryDirect.tokenOut,
                _getGasEstimate(_queryDirect.adapter, _tokenOutPriceNwei)
            );
            _amountOut = _queryDirect.amountOut;
            _gasCost = _getGasCost(_tokenOutPriceNwei, _bestOption.gasEstimate);
        }
    }

    /**
        @notice Find the gas cost of the transaction, expressed in _token (wei)
        @param _tokenPriceNwei gas price expressed in _token, in nanoWei
        @param _gasEstimate amount of gas units consumed
     */
    function _getGasCost(uint256 _tokenPriceNwei, uint256 _gasEstimate)
        internal
        pure
        returns (uint256)
    {
        return (_tokenPriceNwei * _gasEstimate) / 1e9;
    }

    /**
        @notice Get the estimation for gas units consumed by adapter
        @dev _tokenPriceNwei=0 will ignore the gas consumption
        @param _adapter address of the adapter
        @param _tokenPriceNwei gas price expressed in _token, in nanoWei
     */
    function _getGasEstimate(address _adapter, uint256 _tokenPriceNwei)
        internal
        view
        returns (uint256)
    {
        if (_tokenPriceNwei != 0) {
            return IAdapter(_adapter).swapGasEstimate();
        } else {
            return 0;
        }
    }
}
