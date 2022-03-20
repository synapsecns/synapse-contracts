// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./IBasicQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IQuoter is IBasicQuoter {
    // solhint-disable-next-line
    function WGAS() external view returns (address payable);

    // -- FIND BEST PATH --

    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps,
        uint256 _gasPrice
    ) external view returns (Offers.FormattedOfferWithGas memory);
}
