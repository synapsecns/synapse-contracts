// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./IBasicQuoter.sol";

interface IQuoter is IBasicQuoter {
    function queryDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (Query memory);

    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSteps,
        uint256 _gasPrice
    ) external view returns (FormattedOfferWithGas memory);
}
