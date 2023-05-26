// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IndexedToken} from "../libs/Structs.sol";

interface IPoolModule {
    function poolSwap(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function getPoolQuote(
        address pool,
        IndexedToken memory tokenFrom,
        IndexedToken memory tokenTo,
        uint256 amountIn,
        bool probePaused
    ) external view returns (uint256 amountOut);

    function getPoolTokens(address pool, uint256 tokensAmount) external view returns (address[] memory tokens);
}
