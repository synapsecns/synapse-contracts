// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseMigratorTest} from "./SynapseMigrator.t.sol";

contract SynapseMigratorLessDecimalsTest is SynapseMigratorTest {
    constructor() SynapseMigratorTest(18, 6) {}

    function test_migrate_precisionLoss() public {
        amount = 1.23456789 * 10**18;
        expectedNewAmount = 1234567;
        test_migrate();
    }

    function test_migrate_revert_precisionLoss_zeroAmountOut() public {
        vm.expectRevert(SM__ZeroAmount.selector);
        vm.prank(user);
        migrator.migrate(address(oldToken), 10**12 - 1);
    }

    function test_previewMigrate_precisionLoss() public {
        amount = 1.23456789 * 10**18;
        expectedNewAmount = 1234567;
        test_previewMigrate();
    }

    function test_previewMigrate_precisionLoss_zeroAmountOut() public {
        amount = 10**12 - 1;
        expectedNewAmount = 0;
        test_previewMigrate();
    }
}
