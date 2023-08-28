// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseRouterV2} from "../../contracts/router/SynapseRouterV2.sol";
import {BridgeFailed, ModuleExists, ModuleNotExists, ModuleInvalid, QueryEmpty} from "../../contracts/router/libs/Errors.sol";

import {SwapQuoterV2} from "../../contracts/router/quoter/SwapQuoterV2.sol";
import {DefaultPoolCalc} from "../../contracts/router/quoter/DefaultPoolCalc.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockWETH} from "./mocks/MockWETH.sol";
// TODO: import {MockBridge} from "../mocks/MockBridge.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterV2Test is Test {
    event QuoterSet(address oldSwapQuoter, address newSwapQuoter);
    event ModuleConnected(bytes32 indexed moduleId, address bridgeModule);
    event ModuleUpdated(bytes32 indexed moduleId, address oldBridgeModule, address newBridgeModule);
    event ModuleDisconnected(bytes32 indexed moduleId);

    MockERC20 public bridgeToken;
    MockERC20 public token0;
    MockERC20 public token1;
    MockWETH public WETH;

    // TODO: Bridge supporting token, Token0, Token1
    // MockBridgeModule public bridgeB01;

    SynapseRouterV2 public router;
    SwapQuoterV2 public quoter;
    DefaultPoolCalc public defaultPoolCalc;

    address public owner;
    address public user;
    address public bridgeModule;

    function setUp() public virtual {
        user = makeAddr("User");
        owner = makeAddr("Owner");

        bridgeToken = setupERC20("BT", 18);
        token0 = setupERC20("T0", 18);
        token1 = setupERC20("T1", 6);
        WETH = setupWETH();

        setupBridgeModule("BM", address(0xB));

        vm.prank(owner);
        router = new SynapseRouterV2();

        defaultPoolCalc = new DefaultPoolCalc();
        quoter = new SwapQuoterV2(address(router), address(defaultPoolCalc), address(WETH), owner);
    }

    function testSetup() public {
        assertEq(address(router.swapQuoter()), address(0));
    }

    function test_setSwapQuoter() public {
        vm.prank(owner);
        router.setSwapQuoter(quoter);
        assertEq(address(router.swapQuoter()), address(quoter));
    }

    function test_setSwapQuoter_emit_quoterSet() public {
        vm.expectEmit();
        emit QuoterSet(address(0), address(quoter));

        vm.prank(owner);
        router.setSwapQuoter(quoter);
    }

    function test_setSwapQuoter_revert_callerNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        router.setSwapQuoter(quoter);
    }

    function test_connectBridgeModule(bytes32 moduleId, address module) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(module != address(0));

        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);
        assertEq(router.idToModule(moduleId), module);
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
        vm.expectRevert("Ownable: caller is not the owner");
        router.connectBridgeModule(moduleId, module);
    }

    function test_connectBridgeModule_revert_moduleInvalid(bytes32 moduleId, address module) public {
        vm.expectRevert(ModuleInvalid.selector);
        vm.prank(owner);
        router.connectBridgeModule(bytes32(0), module);

        vm.expectRevert(ModuleInvalid.selector);
        vm.prank(owner);
        router.connectBridgeModule(moduleId, address(0));
    }

    function test_connectBridgeModule_revert_moduleExists(bytes32 moduleId, address module) public {
        // connect first
        vm.prank(owner);
        router.connectBridgeModule(moduleId, module);

        // should fail if reuse moduleId
        vm.expectRevert(ModuleExists.selector);
        vm.prank(owner);
        router.connectBridgeModule(moduleId, address(0xA));
    }

    function setupERC20(string memory name, uint8 decimals) public returns (MockERC20 token) {
        token = new MockERC20(name, decimals);
        vm.label(address(token), name);
    }

    function setupWETH() public returns (MockWETH weth) {
        weth = new MockWETH();
        vm.label(address(weth), "WETH");
    }

    function setupBridgeModule(string memory name, address module) public {
        bridgeModule = module;
        vm.label(module, name);
    }
}
