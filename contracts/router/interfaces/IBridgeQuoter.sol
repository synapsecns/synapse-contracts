// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IQuoter} from "./IQuoter.sol";

interface IBridgeQuoter is IQuoter {
    function getBridgeDataAmountOut(
        bytes4 _selector,
        address _to,
        address _bridgeToken,
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _gasPrice,
        uint256 _maxSwapSlippage
    ) external view returns (bytes memory _bridgeData, uint256 _amountOut);
}
