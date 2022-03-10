// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasicQuoter {
    event UpdatedTrustedTokens(address[] _newTrustedTokens);

    event AddedTrustedToken(address _newTrustedTokens);

    event RemovedToken(address _removedTokens);

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

    function getTrustedToken(uint8 _index) external view returns (address);

    function trustedTokensCount() external view returns (uint256);

    // -- TOKEN FUNCTIONS --

    function addTrustedToken(address _token) external;

    function removeToken(address _token) external;

    function removeTokenByIndex(uint8 _index) external;

    // -- SETTERS --

    function setMaxSteps(uint8 _maxSteps) external;

    function setTokens(address[] memory _tokens) external;
}
