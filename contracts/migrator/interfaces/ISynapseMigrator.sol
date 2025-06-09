// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISynapseMigrator {
    /// @notice Allows the contract owner to add a token pair to the migrator.
    /// Users will be able to migrate from the old token to the new token using 1:1 ratio,
    /// taking token decimals into account.
    /// @dev Will revert in the following cases:
    /// - Either of the tokens is the zero address.
    /// - Token addresses are the same.
    /// - The token pair is already added for the old token.
    function addTokenPair(address oldToken, address newToken) external;

    /// @notice Migrates the given amount of old tokens to new tokens.
    /// Old tokens will be taken from the user and burned. New tokens will be transferred to the user.
    /// @dev Will revert in the following cases:
    /// - Zero address or amount is supplied.
    /// - The token pair is not added for the old token.
    /// - Contract does not have enough balance of the new token.
    function migrate(address oldToken, uint256 amount) external;

    /// @notice Returns the new token for the given old token.
    /// @dev Will return the zero address if the token pair is not added for the old token.
    function getTokenPair(address oldToken) external view returns (address newToken);

    /// @notice Returns the new token and amount of new tokens that will be received for the given amount of old tokens.
    /// @dev Will return (address(0), 0) if the token pair is not added for the old token.
    function previewMigrate(address oldToken, uint256 amount)
        external
        view
        returns (address newToken, uint256 newAmount);
}
