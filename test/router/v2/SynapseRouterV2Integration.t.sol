// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../utils/IntegrationUtils.sol";

import {ISwapQuoterV2} from "../../../contracts/router/interfaces/ISwapQuoterV2.sol";
import {IBridgeModule} from "../../../contracts/router/interfaces/IBridgeModule.sol";

import {Arrays} from "../../../contracts/router/libs/Arrays.sol";
import {BridgeToken, SwapQuery} from "../../../contracts/router/libs/Structs.sol";

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
    using Arrays for BridgeToken[];
    using Arrays for address[];

    ISwapQuoterV2 private _quoter;

    uint256[] public expectedChainIds; // destination chain ids to support

    address[] public expectedModules;
    mapping(address => string) public moduleNames;
    mapping(address => bytes32) public moduleIds;

    address[] public expectedTokens;
    mapping(address => string) public tokenNames;

    // synapse bridge module
    address public synapseLocalBridgeConfig;
    address public synapseBridge;

    // synapse cctp module
    address public synapseCCTP;

    SynapseRouterV2 public router;
    address public user;
    address public recipient;

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
        if (synapseCCTP != address(0)) deploySynapseCCTPModule();

        addExpectedChainIds();
        addExpectedModules();
        addExpectedTokens();

        connectBridgeModules();
        user = makeAddr("User");
        recipient = makeAddr("Recipient");
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

    /// @dev override to include destination chains
    function addExpectedChainIds() public virtual;

    /// @dev override to include more modules than bridge, cctp
    function addExpectedModules() public virtual;

    function addExpectedModule(address module, string memory moduleName) public virtual {
        expectedModules.push(module);
        moduleNames[module] = moduleName;
        moduleIds[module] = getModuleId(moduleName);
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

    // TODO: add separate bridge tests with origin, dest query
    function testBridges() public {
        SwapQuery memory emptyQuery;
        for (uint256 i = 0; i < expectedModules.length; i++) {
            address module = expectedModules[i];
            bytes32 moduleId = moduleIds[module];
            for (uint256 j = 0; j < expectedTokens.length; j++) {
                address token = expectedTokens[j];
                address[] memory supportedTokens = IBridgeModule(module).getBridgeTokens().tokens();
                if (!supportedTokens.contains(token)) continue; // test not relevant if module doesn't support token
                for (uint256 k = 0; k < expectedChainIds.length; k++) {
                    uint256 chainId = expectedChainIds[k];
                    checkBridge(chainId, moduleId, token, emptyQuery, emptyQuery);
                }
            }
        }
    }

    function checkBridge(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) public virtual {
        uint256 amount = getTestAmount(token);
        mintToken(token, amount);
        approveSpending(token, address(router), amount);

        // TODO: include swap query params in logs, factor in getters check
        console.log("Bridging %s from chain %s -> %s", tokenNames[token], getChainId(), chainId);
        uint256 balanceBefore = IERC20(token).balanceOf(user);
        vm.prank(user);
        router.bridgeViaSynapse({
            to: recipient,
            chainId: chainId,
            moduleId: moduleId,
            token: token,
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
        assertEq(IERC20(token).balanceOf(user), balanceBefore - amount, "Failed to spend token");
        checkBridgeEvent(chainId, moduleId, token, amount, originQuery, destQuery);
    }

    function checkBridgeEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) public virtual {
        if (moduleId == getModuleId("SynapseBridgeModule"))
            checkSynapseBridgeEvent(chainId, moduleId, token, amount, originQuery, destQuery);
        else if (moduleId == getModuleId("SynapseCCTPModule"))
            checkSynapseCCTPEvent(chainId, moduleId, token, amount, originQuery, destQuery);
        else checkExpectedBridgeEvent(chainId, moduleId, token, amount, originQuery, destQuery);
    }

    function checkSynapseBridgeEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) public {
        if (moduleId != getModuleId("SynapseBridgeModule")) return;
        // TODO:
    }

    function checkSynapseCCTPEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) public {
        if (moduleId != getModuleId("SynapseCCTPModule")) return;
        // TODO:
    }

    /// @dev Override for events to listen for with additional expected modules
    function checkExpectedBridgeEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) public virtual;

    // TODO:
    function testSwaps() public {}

    // TODO:
    function checkSwap() public virtual {}

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function getModuleId(string memory moduleName) public returns (bytes32) {
        return keccak256(abi.encodePacked(moduleName));
    }

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
