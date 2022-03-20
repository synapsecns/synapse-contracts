// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQuoter} from "./IQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IBridgeQuoter is IQuoter {
    function findBestPathInitialChain(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _gasPrice
    ) external view returns (Offers.FormattedOfferWithGas memory _bestOffer);

    function findBestPathDestinationChain(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _gasPrice
    ) external view returns (Offers.FormattedOfferWithGas memory _bestOffer);
}
