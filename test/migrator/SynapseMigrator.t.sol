// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseMigrator, ISynapseMigratorErrors} from "../../contracts/migrator/SynapseMigrator.sol";

import {MockBurnableToken} from "../mocks/MockBurnableToken.sol";

import {Test} from "forge-std/Test.sol";

abstract contract SynapseMigratorTest is Test, ISynapseMigratorErrors {
    event Migrated(address indexed user, address indexed oldToken, uint256 amount);

    SynapseMigrator internal migrator;
    MockBurnableToken internal oldToken;
    MockBurnableToken internal newToken;

    uint8 internal oldTokenDecimals;
    uint8 internal newTokenDecimals;

    address internal user = makeAddr("user");
    uint256 internal oldTokenBalance;
    uint256 internal newTokenSupply;
    uint256 internal amount;
    uint256 internal expectedNewAmount;

    constructor(uint8 oldTokenDecimals_, uint8 newTokenDecimals_) {
        oldTokenDecimals = oldTokenDecimals_;
        newTokenDecimals = newTokenDecimals_;
    }

    function setUp() public {
        migrator = new SynapseMigrator(address(this));
        oldToken = new MockBurnableToken("OldToken", oldTokenDecimals);
        newToken = new MockBurnableToken("NewToken", newTokenDecimals);
        migrator.addTokenPair(address(oldToken), address(newToken));

        // 10 tokens
        oldTokenBalance = 10 * 10**oldTokenDecimals;
        newTokenSupply = 10 * 10**newTokenDecimals;
        // Migrate 1 token
        amount = 10**oldTokenDecimals;
        expectedNewAmount = 10**newTokenDecimals;

        oldToken.mintTestTokens(user, oldTokenBalance);
        newToken.mintTestTokens(address(migrator), newTokenSupply);

        vm.prank(user);
        oldToken.approve(address(migrator), type(uint256).max);
    }

    function test_migrate() public {
        vm.expectEmit(address(migrator));
        emit Migrated(user, address(oldToken), amount);
        vm.prank(user);
        migrator.migrate(address(oldToken), amount);
        // Old token balances
        assertEq(oldToken.balanceOf(user), oldTokenBalance - amount);
        assertEq(oldToken.balanceOf(address(migrator)), 0);
        assertEq(oldToken.totalSupply(), oldTokenBalance - amount);
        // New token balances
        assertEq(newToken.balanceOf(user), expectedNewAmount);
        assertEq(newToken.balanceOf(address(migrator)), newTokenSupply - expectedNewAmount);
        assertEq(newToken.totalSupply(), newTokenSupply);
    }

    function test_migrate_revert_oldTokenNotAdded() public {
        // Redeploy migrator to effectively remove the token pair
        migrator = new SynapseMigrator(address(this));
        vm.expectRevert(SM__TokenPairNotAdded.selector);
        vm.prank(user);
        migrator.migrate(address(oldToken), amount);
    }

    function test_migrate_revert_oldTokenZero() public {
        vm.expectRevert(SM__ZeroAddress.selector);
        vm.prank(user);
        migrator.migrate(address(0), amount);
    }

    function test_migrate_revert_amountZero() public {
        vm.expectRevert(SM__ZeroAmount.selector);
        vm.prank(user);
        migrator.migrate(address(oldToken), 0);
    }

    function test_migrate_revert_notEnoughAllowance() public {
        vm.prank(user);
        oldToken.approve(address(migrator), amount - 1);
        vm.expectRevert();
        vm.prank(user);
        migrator.migrate(address(oldToken), amount);
    }

    function test_previewMigrate() public {
        uint256 previewedAmount = migrator.previewMigrate(address(oldToken), amount);
        assertEq(previewedAmount, expectedNewAmount);
    }

    function test_previewMigrate_returnsZero_tokenNotAdded() public {
        migrator = new SynapseMigrator(address(this));
        uint256 previewedAmount = migrator.previewMigrate(address(oldToken), amount);
        assertEq(previewedAmount, 0);
    }
}
