// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicQuoter {
    event UpdatedTrustedAdapters(address[] _newTrustedAdapters);

    event AddedTrustedAdapter(address _newTrustedAdapter);

    event RemovedAdapter(address _removedAdapter);

    event RemovedAdapters(address[] _removedAdapters);

    event UpdatedTrustedTokens(address[] _newTrustedTokens);

    event AddedTrustedToken(address _newTrustedToken);

    event RemovedToken(address _removedToken);

    struct Query {
        address adapter;
        address tokenIn;
        address tokenOut;
        uint256 amountOut;
    }

    struct OfferWithGas {
        bytes amounts;
        bytes adapters;
        bytes path;
        uint256 gasEstimate;
    }

    struct FormattedOfferWithGas {
        uint256[] amounts;
        address[] adapters;
        address[] path;
        uint256 gasEstimate;
    }

    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address[] adapters;
    }

    //  -- VIEWS --

    function getTrustedAdapter(uint8 _index) external view returns (address);

    function getTrustedToken(uint8 _index) external view returns (address);

    function trustedAdaptersCount() external view returns (uint256);

    function trustedTokensCount() external view returns (uint256);

    // -- ADAPTER FUNCTIONS --

    function addTrustedAdapter(address _adapter) external;

    function removeAdapter(address _adapter) external;

    function removeAdapterByIndex(uint8 _index) external;

    // -- TOKEN FUNCTIONS --

    function addTrustedToken(address _token) external;

    function removeToken(address _token) external;

    function removeTokenByIndex(uint8 _index) external;

    // -- SETTERS --

    function setAdapters(address[] calldata _adapters) external;

    function setMaxSwaps(uint8 _maxSwaps) external;

    function setTokens(address[] memory _tokens) external;
}
