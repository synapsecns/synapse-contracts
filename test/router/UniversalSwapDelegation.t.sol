// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {UniversalSwapTest} from "./UniversalSwap.t.sol";

import {MockPoolModule} from "../mocks/MockPoolModule.sol";

// solhint-disable func-name-mixedcase
contract UniversalSwapDelegationTest is UniversalSwapTest {
    function setUp() public virtual override {
        poolModule = address(new MockPoolModule());
        super.setUp();
    }
}
