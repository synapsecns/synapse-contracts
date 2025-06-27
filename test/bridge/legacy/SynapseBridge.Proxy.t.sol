// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Test} from "forge-std/Test.sol";

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SynapseBridge} from "../../../contracts/bridge/SynapseBridge.sol";

// solhint-disable func-name-mixedcase
abstract contract SynapseBridgeProxyTest is Test {
    SynapseBridge internal bridge;
    address internal implementation;

    function setUp() public virtual {
        implementation = address(new SynapseBridge());
        // Tests don't need to assume the exact proxy structure, so we can use a minimal proxy.
        bridge = SynapseBridge(payable(Clones.clone(implementation)));
    }

    function test_initialize_implementation_revert() public {
        vm.expectRevert("Initializable: contract is already initialized");
        SynapseBridge(payable(implementation)).initialize();
    }
}
