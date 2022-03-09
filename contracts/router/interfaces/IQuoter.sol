// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from "./IRouter.sol";
import {IBasicQuoter} from "./IBasicQuoter.sol";

interface IQuoter is IBasicQuoter, IRouter {
    function queryDirectAdapter(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _index
    ) external view returns (uint256);

    function queryDirectAdapters(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8[] calldata _options
    ) external view returns (Query memory);

    function queryDirectAllAdapters(
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
