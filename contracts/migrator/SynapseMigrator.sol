// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISynapseMigrator} from "./interfaces/ISynapseMigrator.sol";
import {ISynapseMigratorErrors} from "./interfaces/ISynapseMigratorErrors.sol";

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";

contract SynapseMigrator is Ownable, ISynapseMigrator, ISynapseMigratorErrors {
    event Migrated(address indexed user, address indexed oldToken, uint256 amount);
    event TokenPairAdded(address indexed oldToken, address indexed newToken);

    constructor(address owner_) {
        transferOwnership(owner_);
    }

    /// @inheritdoc ISynapseMigrator
    function addTokenPair(address oldToken, address newToken) external onlyOwner {
        // TODO: implement
    }

    /// @inheritdoc ISynapseMigrator
    function migrate(address oldToken, uint256 amount) external {
        // TODO: implement
    }

    /// @inheritdoc ISynapseMigrator
    function getTokenPair(address oldToken) external view returns (address newToken) {
        // TODO: implement
    }

    /// @inheritdoc ISynapseMigrator
    function previewMigrate(address oldToken, uint256 amount) external view returns (uint256 newAmount) {
        // TODO: implement
    }
}
