// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGMXV1Vault {
    function whitelistedTokenCount() external view returns (uint256);

    function allWhitelistedTokens(uint256) external view returns (address);
}
