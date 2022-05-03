// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicQuoter {
    event UpdatedTrustedAdapters(address[] newTrustedAdapters);

    event AddedTrustedAdapter(address newTrustedAdapter);

    event RemovedAdapter(address removedAdapter);

    event RemovedAdapters(address[] removedAdapters);

    event UpdatedTrustedTokens(address[] newTrustedTokens);

    event AddedTrustedToken(address newTrustedToken);

    event RemovedToken(address removedToken);

    struct Query {
        address adapter;
        address tokenIn;
        address tokenOut;
        uint256 amountOut;
    }

    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address[] adapters;
    }

    //  -- VIEWS --

    function getTrustedAdapter(uint8 index) external view returns (address);

    function getTrustedToken(uint8 index) external view returns (address);

    function trustedAdaptersCount() external view returns (uint256);

    function trustedTokensCount() external view returns (uint256);

    // -- ADAPTER FUNCTIONS --

    function addTrustedAdapter(address adapter) external;

    function removeAdapter(address adapter) external;

    function removeAdapterByIndex(uint8 index) external;

    // -- TOKEN FUNCTIONS --

    function addTrustedToken(address token) external;

    function removeToken(address token) external;

    function removeTokenByIndex(uint8 index) external;

    // -- SETTERS --

    function setAdapters(address[] calldata adapters) external;

    function setMaxSwaps(uint8 maxSwaps) external;

    function setTokens(address[] memory tokens) external;
}
