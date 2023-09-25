// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../utils/IntegrationUtils.sol";

import {ISwapQuoterV2} from "../../../contracts/router/interfaces/ISwapQuoterV2.sol";
import {IBridgeModule} from "../../../contracts/router/interfaces/IBridgeModule.sol";

import {SynapseRouterV2} from "../../../contracts/router/SynapseRouterV2.sol";
import {SynapseBridgeModule} from "../../../contracts/router/modules/bridge/SynapseBridgeModule.sol";
import {SynapseCCTPModule} from "../../../contracts/router/modules/bridge/SynapseCCTPModule.sol";

import {console, Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable no-console
abstract contract SynapseRouterV2IntegrationTest is IntegrationUtils {
    using SafeERC20 for IERC20;

    ISwapQuoterV2 private _quoter;

    address[] public expectedModules;
    mapping(address => string) public moduleNames;
    mapping(address => bytes32) public moduleIds;

    address[] public expectedTokens;
    mapping(address => string) public tokenNames;

    // synapse bridge module
    address public synapseLocalBridgeConfig;
    address public synapseBridge;

    // synapse cctp module
    bool public hasCCTP;
    address public synapseCCTP;

    SynapseRouterV2 public router;
    address public user;

    constructor(
        string memory envRPC,
        uint256 forkBlockNumber,
        address quoter
    ) IntegrationUtils(envRPC, forkBlockNumber) {
        require(quoter != address(0), "swapQuoter == address(0)");
        _quoter = ISwapQuoterV2(quoter);
    }

    function setUp() public virtual override {
        super.setUp(); // @dev afterBlockchainForked() should be overwritten for extra config here

        deployRouter();
        setSwapQuoter();

        deploySynapseBridgeModule();
        if (hasCCTP) deploySynapseCCTPModule();
        addExpectedModules();
        connectBridgeModules();

        addExpectedTokens();
        user = makeAddr("User");
    }

    function deployRouter() public virtual {
        router = new SynapseRouterV2();
    }

    function setSwapQuoter() public virtual {
        router.setSwapQuoter(_quoter);
    }

    function deploySynapseBridgeModule() public virtual {
        require(synapseLocalBridgeConfig != address(0), "synapseLocalBridgeConfig == address(0)");
        require(synapseBridge != address(0), "synapseBridge == address(0)");

        address module = address(new SynapseBridgeModule(synapseLocalBridgeConfig, synapseBridge));
        addExpectedModule(module, "SynapseBridgeModule");
    }

    function deploySynapseCCTPModule() public virtual {
        require(synapseCCTP != address(0), "synapseCCTP == address(0)");

        address module = address(new SynapseCCTPModule(synapseCCTP));
        addExpectedModule(module, "SynapseCCTPModule");
    }

    /// @dev override to include more modules than bridge, cctp
    function addExpectedModules() public virtual;

    function addExpectedModule(address module, string memory moduleName) public virtual {
        expectedModules.push(module);
        moduleNames[module] = moduleName;
        moduleIds[module] = keccak256(abi.encodePacked(moduleName));
        vm.label(module, moduleName);
    }

    function connectBridgeModules() public virtual {
        for (uint256 i = 0; i < expectedModules.length; i++) {
            address module = expectedModules[i];
            bytes32 id = moduleIds[module];
            router.connectBridgeModule(id, module);
        }
    }

    function addExpectedTokens() public virtual;

    function addExpectedToken(address token, string memory tokenName) public virtual {
        expectedTokens.push(token);
        tokenNames[token] = tokenName;
        vm.label(token, tokenName);
    }

    // ═══════════════════════════════════════════════════ TESTS ═══════════════════════════════════════════════════════

    // TODO: tests for views: generic getters, origin/destination getAmountOut

    function testSetup() public {
        for (uint256 i = 0; i < expectedModules.length; i++) {
            console.log("%s: %s [%s]", i, expectedModules[i], moduleNames[expectedModules[i]]);
            assertEq(router.moduleToId(expectedModules[i]), moduleIds[expectedModules[i]]);
        }
    }

    // TODO:
    function testBridges() public {}

    // TODO:
    function testSwaps() public {}

    // TODO:
    function checkBridges() public virtual {}

    // TODO:
    function checkSwap() public virtual {}

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function getTestAmount(address token) public view virtual returns (uint256) {
        // 0.01 units in the token decimals
        return 10**uint256(IERC20Metadata(token).decimals() - 2);
    }

    // Could be overridden if `deal` does not work with the token
    function mintToken(address token, uint256 amount) public virtual {
        deal(token, user, amount);
    }

    function approveSpending(
        address token,
        address spender,
        uint256 amount
    ) public {
        vm.startPrank(user);
        IERC20(token).safeApprove(spender, amount);
        vm.stopPrank();
    }
}
