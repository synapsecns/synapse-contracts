// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGmxVault {
    // -- VIEWS --
    function allWhitelistedTokens(uint256 _index) external view returns (address);

    function allWhitelistedTokensLength() external view returns (uint256);

    // -- SWAP --
    function swap(
        address _tokenIn,
        address _tokenOut,
        address _receiver
    ) external returns (uint256);
}
