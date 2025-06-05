// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseMigratorTest} from "./SynapseMigrator.t.sol";

contract SynapseMigratorMoreDecimalsTest is SynapseMigratorTest {
    constructor() SynapseMigratorTest(6, 18) {}
}
