// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {QuoteExactInputSingleParams} from "./AlgebraStructs.sol";

interface IAlgebraStaticQuoter {
    function quoteExactInputSingle(QuoteExactInputSingleParams memory params) external view returns (uint256 amountOut);
}
