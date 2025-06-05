// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IBurnable} from "./interfaces/IBurnable.sol";
import {ISynapseMigrator} from "./interfaces/ISynapseMigrator.sol";
import {ISynapseMigratorErrors} from "./interfaces/ISynapseMigratorErrors.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";

contract SynapseMigrator is Ownable, ISynapseMigrator, ISynapseMigratorErrors {
    using SafeERC20 for IERC20;

    struct TokenPair {
        address newToken;
        uint8 oldTokenDecimals;
        uint8 newTokenDecimals;
    }

    mapping(address => TokenPair) internal _tokenPairs;

    event Migrated(address indexed user, address indexed oldToken, uint256 amount);
    event TokenPairAdded(address indexed oldToken, address indexed newToken);

    constructor(address owner_) {
        transferOwnership(owner_);
    }

    /// @inheritdoc ISynapseMigrator
    function addTokenPair(address oldToken, address newToken) external onlyOwner {
        if (oldToken == address(0) || newToken == address(0)) revert SM__ZeroAddress();
        if (oldToken == newToken) revert SM__SameAddress();
        // Check that the token pair has not been added yet
        if (_tokenPairs[oldToken].newToken != address(0)) revert SM__TokenPairAlreadyAdded();
        // Add token pair and record the tokens decimals to avoid extra calls in the future
        _tokenPairs[oldToken] = TokenPair({
            newToken: newToken,
            oldTokenDecimals: IERC20Metadata(oldToken).decimals(),
            newTokenDecimals: IERC20Metadata(newToken).decimals()
        });
        emit TokenPairAdded(oldToken, newToken);
    }

    /// @inheritdoc ISynapseMigrator
    function migrate(address oldToken, uint256 amount) external {
        if (oldToken == address(0)) revert SM__ZeroAddress();
        (address newToken, uint256 newAmount) = _previewMigrate(oldToken, amount);
        if (newToken == address(0)) revert SM__TokenPairNotAdded();
        if (newAmount == 0) revert SM__ZeroAmount();
        // Burn old tokens from the user
        IBurnable(oldToken).burnFrom(msg.sender, amount);
        // Send new tokens to the user
        IERC20(newToken).safeTransfer(msg.sender, newAmount);
        emit Migrated(msg.sender, oldToken, amount);
    }

    /// @inheritdoc ISynapseMigrator
    function getTokenPair(address oldToken) external view returns (address newToken) {
        return _tokenPairs[oldToken].newToken;
    }

    /// @inheritdoc ISynapseMigrator
    function previewMigrate(address oldToken, uint256 amount) public view returns (uint256 newAmount) {
        (, newAmount) = _previewMigrate(oldToken, amount);
    }

    /// @dev Internal function to preview the amount of new tokens that will be received
    function _previewMigrate(address oldToken, uint256 amount)
        internal
        view
        returns (address newToken, uint256 newAmount)
    {
        newToken = _tokenPairs[oldToken].newToken;
        uint256 oldDecimals = _tokenPairs[oldToken].oldTokenDecimals;
        uint256 newDecimals = _tokenPairs[oldToken].newTokenDecimals;
        if (newToken == address(0)) return (address(0), 0);
        newAmount = (amount * 10**newDecimals) / 10**oldDecimals;
    }
}
