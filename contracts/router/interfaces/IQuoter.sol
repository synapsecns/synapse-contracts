// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./IBasicQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IQuoter is IBasicQuoter {
    function findBestPath(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint8 maxSwaps
    ) external view returns (Offers.FormattedOffer memory);
}
