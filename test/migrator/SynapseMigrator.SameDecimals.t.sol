// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseMigratorTest} from "./SynapseMigrator.t.sol";

contract SynapseMigratorSameDecimalsTest is SynapseMigratorTest {
    constructor() SynapseMigratorTest(18, 18) {}
}
