// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSynapseRouterV2Test} from "./BasicSynapseRouterV2.t.sol";
import {ModuleExists, ModuleNotExists, ModuleInvalid} from "../../../contracts/router/libs/Errors.sol";
import {SwapQuoterV2} from "../../../contracts/router/quoter/SwapQuoterV2.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterV2ManagementTest is BasicSynapseRouterV2Test {
    event QuoterSet(address oldSwapQuoter, address newSwapQuoter);
    event ModuleConnected(bytes32 indexed moduleId, address bridgeModule);
    event ModuleUpdated(bytes32 indexed moduleId, address oldBridgeModule, address newBridgeModule);
    event ModuleDisconnected(bytes32 indexed moduleId);

    function deployQuoter() public returns (SwapQuoterV2 q) {
        q = new SwapQuoterV2({
            synapseRouter_: synapseRouter,
            defaultPoolCalc_: defaultPoolCalc,
            weth_: weth,
            owner_: owner
        });
    }

    function testSetup() public {
        assertEq(address(router.swapQuoter()), address(quoter));
        assertEq(address(quoter.synapseRouter()), address(router));
    }

    function test_setSwapQuoter() public {
        SwapQuoterV2 newSwapQuoter = deployQuoter();

        vm.prank(owner);
        router.setSwapQuoter(newSwapQuoter);
        assertEq(address(router.swapQuoter()), address(newSwapQuoter));
    }

    function test_setSwapQuoter_emit_quoterSet() public {
        SwapQuoterV2 newSwapQuoter = deployQuoter();

        vm.expectEmit();
        emit QuoterSet(address(quoter), address(newSwapQuoter));

        vm.prank(owner);
        router.setSwapQuoter(newSwapQuoter);
    }

    function test_setSwapQuoter_revert_callerNotOwner() public {
        SwapQuoterV2 newSwapQuoter = deployQuoter();

        vm.expectRevert("Ownable: caller is not the owner");
        router.setSwapQuoter(newSwapQuoter);
    }

    function test_connectBridgeModule(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);
        assertEq(router.idToModule(moduleId), module);
        assertEq(router.moduleToId(module), moduleId);
    }

    function test_connectBridgeModule_emit_moduleConnected(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        vm.expectEmit();
        emit ModuleConnected(moduleId, module);

        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);
    }

    function test_connectBridgeModule_revert_callerNotOwner(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        vm.expectRevert("Ownable: caller is not the owner");
        router.connectBridgeModule(moduleId, module);
    }

    function test_connectBridgeModule_revert_moduleInvalid(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        vm.expectRevert(ModuleInvalid.selector);
        vm.prank(owner);
        router.connectBridgeModule(bytes32(0), module);

        vm.expectRevert(ModuleInvalid.selector);
        vm.prank(owner);
        router.connectBridgeModule(moduleId, address(0));
    }

    function test_connectBridgeModule_revert_moduleExists(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);

        // should fail if reuse moduleId
        vm.expectRevert(ModuleExists.selector);
        vm.prank(owner);
        router.connectBridgeModule(moduleId, address(0xA));
    }

    function test_updateBridgeModule(
        bytes32 moduleId,
        address oldModule,
        address newModule
    ) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(oldModule != address(0));
        vm.assume(newModule != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, oldModule);

        vm.prank(owner);
        router.updateBridgeModule(moduleId, newModule);
        assertEq(router.idToModule(moduleId), newModule);
        assertEq(router.moduleToId(newModule), moduleId);

        if (oldModule != newModule) {
            vm.expectRevert(ModuleNotExists.selector);
            router.moduleToId(oldModule);
        }
    }

    function test_updateBridgeModule_emit_moduleUpdated(
        bytes32 moduleId,
        address oldModule,
        address newModule
    ) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(oldModule != address(0));
        vm.assume(newModule != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, oldModule);

        vm.expectEmit();
        emit ModuleUpdated(moduleId, oldModule, newModule);

        vm.prank(owner);
        router.updateBridgeModule(moduleId, newModule);
    }

    function test_updateBridgeModule_revert_callerNotOwner(
        bytes32 moduleId,
        address oldModule,
        address newModule
    ) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(oldModule != address(0));
        vm.assume(newModule != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, oldModule);

        vm.expectRevert("Ownable: caller is not the owner");
        router.updateBridgeModule(moduleId, newModule);
    }

    function test_updateBridgeModule_revert_moduleInvalid(bytes32 moduleId, address oldModule) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(oldModule != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, oldModule);

        vm.expectRevert(ModuleInvalid.selector);
        vm.prank(owner);
        router.updateBridgeModule(moduleId, address(0));
    }

    function test_updateBridgeModule_revert_moduleNotExists(bytes32 moduleId, address newModule) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(newModule != address(0));

        vm.expectRevert(ModuleNotExists.selector);
        vm.prank(owner);
        router.updateBridgeModule(moduleId, newModule);
    }

    function test_disconnectBridgeModule(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);

        vm.prank(owner);
        router.disconnectBridgeModule(moduleId);

        vm.expectRevert(ModuleNotExists.selector);
        router.idToModule(moduleId);

        vm.expectRevert(ModuleNotExists.selector);
        router.moduleToId(module);
    }

    function test_disconnectBridgeModule_emit_moduleDisconnected(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);

        vm.expectEmit();
        emit ModuleDisconnected(moduleId);

        vm.prank(owner);
        router.disconnectBridgeModule(moduleId);
    }

    function test_disconnectBridgeModule_revert_callerNotOwner(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);

        vm.expectRevert("Ownable: caller is not the owner");
        router.disconnectBridgeModule(moduleId);
    }

    function test_disconnectBridgeModule_revert_moduleNotExists(bytes32 moduleId) public {
        vm.expectRevert(ModuleNotExists.selector);
        vm.prank(owner);
        router.disconnectBridgeModule(moduleId);
    }
}
