// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {ExactInputSingleParams} from "./AlgebraStructs.sol";

interface IAlgebraRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256 amountOut);
}
