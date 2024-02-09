// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IBridgeConfigV3 {
    struct Token {
        uint256 chainId;
        string tokenAddress;
        uint8 tokenDecimals;
        uint256 maxSwap;
        uint256 minSwap;
        uint256 swapFee;
        uint256 maxSwapFee;
        uint256 minSwapFee;
        bool hasUnderlying;
        bool isUnderlying;
    }

    struct Pool {
        address tokenAddress;
        uint256 chainId;
        address poolAddress;
        bool metaswap;
    }

    /// @notice Returns a list of all existing token IDs converted to strings
    function getAllTokenIDs() external view returns (string[] memory);

    /// @notice Returns the full token config struct
    /// @param tokenID String input of the token ID for the token
    /// @param chainID Chain ID of which token address + config to get
    function getTokenByID(string memory tokenID, uint256 chainID) external view returns (Token memory token);

    /// @notice Returns the whitelisted pool config for a given token
    function getPoolConfig(address tokenAddress, uint256 chainID) external view returns (Pool memory);
}
