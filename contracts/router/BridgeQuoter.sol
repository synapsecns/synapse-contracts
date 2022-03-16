// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Quoter} from "./Quoter.sol";

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";
import {IBridgeQuoter} from "./interfaces/IBridgeQuoter.sol";

import {Offers} from "./libraries/LibOffers.sol";

contract BridgeQuoter is Quoter, IBridgeQuoter {
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
        this;
    }

    /**
        @notice Find best path and calculate _bridgeData parameter for Router.swapAndBridge()
        @dev getBridgeDataAndAmountOut() is supposed to be called on DESTINATION chain
             Calling Router.swapAndBridge(<...>, _bridgeData) on INITIAL chain
             will bridge funds to THIS chain and do _tokenIn -> _tokenOut swap (best available swap at the moment)
        @param _selector specific selector for bridge function, compatible with _bridgeToken (depositMaxAndSwap, redeemMaxAndSwap, etc)
        @param _to address on destination chain that will receive bridged&swapped funds
        @param _bridgeToken bridge token on initial chain
        @param _amountIn amount of bridged tokens, after applying bridge fees
        @param _tokenIn bridge token on destination chain
        @param _tokenOut final token on destination chain
        @param _gasPrice destination chain's current gas price, in wei
        @param _maxSwapSlippage maximum slippage user is willing to accept for swap on destination chain

        @return _bridgeData calldata parameter for Router.swapAndBridge()
        @return _amountOut expected amount of final tokens user is going to receive on destination chain
     */
    function getBridgeDataAmountOut(
        bytes4 _selector,
        address _to,
        address _bridgeToken,
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _gasPrice,
        uint256 _maxSwapSlippage
    ) external view returns (bytes memory, uint256) {
        (
            Offers.FormattedOfferWithGas memory _bestOffer,
            uint256 _minAmountOut,
            uint256 _amountOut
        ) = _getBestOfferWithSlippage(
            _amountIn,
            _tokenIn,
            _tokenOut,
            IBridgeRouter(router).bridgeMaxSwaps(), // use max swaps for Bridge&Swap tx
            _gasPrice,
            _maxSwapSlippage
        );

        uint256 _chainId;
        assembly {
            _chainId := chainid()
        }

        // TODO check that SynapseBridgeV2 is using these params in this order
        // encode func(to, chainId, token, minAmountOut, path, adapters)
        bytes memory _bridgeData = abi.encodeWithSelector(
            _selector,
            _to,
            _chainId,
            _bridgeToken,
            _minAmountOut,
            _bestOffer.path,
            _bestOffer.amounts
        );

        return (_bridgeData, _amountOut);
    }
}
