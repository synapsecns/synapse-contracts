// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicQuoter} from "./IBasicQuoter.sol";
import {Offers} from "../libraries/LibOffers.sol";

interface IQuoter is IBasicQuoter {

    // solhint-disable-next-line
    function WGAS() external view returns (address payable);

    // -- DIRECT SWAP QUERIES --

    function queryDirectSwap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (Query memory);

    // -- FIND BEST PATH --

    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps,
        uint256 _gasPrice
    ) external view returns (Offers.FormattedOfferWithGas memory);

    function getBridgeDataAmountOut(
        bytes4 _selector,
        address _to,
        address _bridgeToken,
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _gasPrice,
        uint256 _maxSwapSlippage
    ) external view returns (bytes memory, uint256);

    function getTradeDataAmountOut(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _maxSwaps,
        uint256 _gasPrice,
        uint256 _maxSwapSlippage
    ) external view returns (Trade memory, uint256);
}
