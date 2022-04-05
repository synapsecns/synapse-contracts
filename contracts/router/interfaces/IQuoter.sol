// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./IBasicQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IQuoter is IBasicQuoter {
    function findBestPath(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        uint8 _maxSwaps
    ) external view returns (Offers.FormattedOffer memory);
}
