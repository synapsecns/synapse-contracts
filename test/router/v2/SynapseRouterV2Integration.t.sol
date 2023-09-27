// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../utils/IntegrationUtils.sol";

import {ISwapQuoterV2} from "../../../contracts/router/interfaces/ISwapQuoterV2.sol";
import {IBridgeModule} from "../../../contracts/router/interfaces/IBridgeModule.sol";
import {ILocalBridgeConfig} from "../../../contracts/router/interfaces/ILocalBridgeConfig.sol";

import {Arrays} from "../../../contracts/router/libs/Arrays.sol";
import {Action, BridgeToken, DefaultParams, SwapQuery} from "../../../contracts/router/libs/Structs.sol";

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

    /// synapse bridge events
    event TokenDeposit(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenDepositAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );

    event TokenRedeem(address indexed to, uint256 chainId, address token, uint256 amount);
    event TokenRedeemAndSwap(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    );
    event TokenRedeemAndRemove(
        address indexed to,
        uint256 chainId,
        address token,
        uint256 amount,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline
    );

    // TODO: synapse cctp events

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

        checkBridgeEvent(chainId, moduleId, token, amount, originQuery, destQuery);
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
            checkSynapseBridgeEvent(chainId, moduleId, token, amount, destQuery);
        else if (moduleId == getModuleId("SynapseCCTPModule"))
            checkSynapseCCTPEvent(chainId, moduleId, token, amount, destQuery);
        else checkExpectedBridgeEvent(chainId, moduleId, token, amount, destQuery);
    }

    function checkSynapseBridgeEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
        SwapQuery memory destQuery
    ) public {
        if (moduleId != getModuleId("SynapseBridgeModule")) return;

        // 5 cases
        //  1. TokenDeposit: ERC20 asset deposit on this chain and no destQuery
        //  2. TokenDepositAndSwap: ERC20 asset deposit on this chain and destQuery w Action.Swap
        //  3. TokenRedeem: Wrapped syn asset burned and no destQuery
        //  4. TokenRedeemAndSwap: Wrapped syn asset burned and destQuery w Action.Swap
        //  5. TokenRedeemAndRemove: Wrapped syn asset burned and destQuery  w Action.RemoveLiquidity
        (ILocalBridgeConfig.TokenType tokenType, ) = ILocalBridgeConfig(synapseLocalBridgeConfig).config(token);

        vm.expectEmit(synapseBridge); // @dev next call should be to router bridge function
        if (tokenType == ILocalBridgeConfig.TokenType.Deposit) {
            // case 1
            if (!hasParams(destQuery)) {
                emit TokenDeposit(recipient, chainId, token, amount);
                return;
            }

            // case 2
            DefaultParams memory params = abi.decode(destQuery.rawParams, (DefaultParams));
            if (params.action == Action.Swap)
                emit TokenDepositAndSwap(
                    recipient,
                    chainId,
                    token,
                    amount,
                    params.tokenIndexFrom,
                    params.tokenIndexTo,
                    destQuery.minAmountOut,
                    destQuery.deadline
                );
        } else if (tokenType == ILocalBridgeConfig.TokenType.Redeem) {
            // case 3
            if (!hasParams(destQuery)) {
                emit TokenRedeem(recipient, chainId, token, amount);
                return;
            }

            DefaultParams memory params = abi.decode(destQuery.rawParams, (DefaultParams));
            if (params.action == Action.Swap)
                emit TokenRedeemAndSwap(
                    recipient,
                    chainId,
                    token,
                    amount,
                    params.tokenIndexFrom,
                    params.tokenIndexTo,
                    destQuery.minAmountOut,
                    destQuery.deadline
                );
            // case 4
            else if (params.action == Action.RemoveLiquidity)
                emit TokenRedeemAndRemove(
                    recipient,
                    chainId,
                    token,
                    amount,
                    params.tokenIndexTo,
                    destQuery.minAmountOut,
                    destQuery.deadline
                ); // case 5
        }
    }

    function checkSynapseCCTPEvent(
        uint256 chainId,
        bytes32 moduleId,
        address token,
        uint256 amount,
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

    function hasParams(SwapQuery memory destQuery) public returns (bool) {
        return (destQuery.rawParams.length > 0);
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
