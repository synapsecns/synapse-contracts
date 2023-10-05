// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationUtils} from "../../../utils/IntegrationUtils.sol";

import {ISwapQuoterV2} from "../../../../contracts/router/interfaces/ISwapQuoterV2.sol";
import {IBridgeModule} from "../../../../contracts/router/interfaces/IBridgeModule.sol";
import {ILocalBridgeConfig} from "../../../../contracts/router/interfaces/ILocalBridgeConfig.sol";

import {IMessageTransmitter} from "../../../../contracts/cctp/interfaces/IMessageTransmitter.sol";
import {ISynapseCCTPConfig} from "../../../../contracts/cctp/interfaces/ISynapseCCTPConfig.sol";

import {Arrays} from "../../../../contracts/router/libs/Arrays.sol";
import {Action, ActionLib, BridgeToken, DefaultParams, DestRequest, LimitedToken, SwapQuery} from "../../../../contracts/router/libs/Structs.sol";
import {SynapseRouterV2} from "../../../../contracts/router/SynapseRouterV2.sol";

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

    address[] public expectedModules;
    mapping(address => string) public moduleNames;
    mapping(address => bytes32) public moduleIds;

    address[] public expectedTokens;
    mapping(address => string) public tokenNames;

    BridgeToken[] public expectedBridgeTokens;
    mapping(address => BridgeToken[]) public expectedOriginBridgeTokens; // tokenIn => bridgeTokens
    mapping(address => BridgeToken[]) public expectedDestinationBridgeTokens; // tokenOut => bridgeTokens

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
        addExpectedTokens();

        deployRouter();
        setSwapQuoter();

        addExpectedModules();
        /// @dev should add all bridge tokens in addition to which are origin, destination
        addExpectedBridgeTokens();
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

    /// @dev Must implement such that is a subset of router supported tokens
    function addExpectedTokens() public virtual;

    function addExpectedToken(address token, string memory tokenName) public virtual {
        expectedTokens.push(token);
        tokenNames[token] = tokenName;
        vm.label(token, tokenName);
    }

    /// @dev Must implement such that is a subset of router bridge tokens
    function addExpectedBridgeTokens() public virtual;

    function addExpectedBridgeToken(
        BridgeToken memory bridgeToken,
        address[] memory originTokens,
        address[] memory destinationTokens
    ) public virtual {
        expectedBridgeTokens.push(bridgeToken);
        tokenNames[bridgeToken.token] = bridgeToken.symbol;
        vm.label(bridgeToken.token, bridgeToken.symbol);

        // add all tokenIn origin tokens this bridge token is connected to
        for (uint256 i = 0; i < originTokens.length; i++) expectedOriginBridgeTokens[originTokens[i]].push(bridgeToken);

        // add all tokenOut destination tokens this bridge token is connected to
        for (uint256 i = 0; i < destinationTokens.length; i++)
            expectedDestinationBridgeTokens[destinationTokens[i]].push(bridgeToken);
    }

    // ═══════════════════════════════════════════════════ TESTS ═══════════════════════════════════════════════════════

    function testSetup() public {
        for (uint256 i = 0; i < expectedModules.length; i++) {
            console.log("%s: %s [%s]", i, expectedModules[i], moduleNames[expectedModules[i]]);
            assertEq(router.moduleToId(expectedModules[i]), moduleIds[expectedModules[i]]);

            // check all bridge tokens in expected bridge tokens array
            address[] memory tokens = IBridgeModule(expectedModules[i]).getBridgeTokens().tokens();
            for (uint256 j = 0; j < tokens.length; j++) {
                assertTrue(expectedBridgeTokens.tokens().contains(tokens[j]));
                console.log("   %s: %s [%s]", j, tokens[j], tokenNames[tokens[j]]);
            }
        }
        assertTrue(user != address(0), "user not set");
        assertTrue(recipient != address(0), "recipient not set");
    }

    /// @dev Tests that must be implemented
    function testGetBridgeTokens() public virtual;

    function testGetSupportedTokens() public virtual;

    function testGetOriginBridgeTokens() public virtual;

    function testGetDestinationBridgeTokens() public virtual;

    function testGetOriginAmountOut() public virtual;

    function testGetDestinationAmountOut() public virtual;

    function testBridges() public virtual;

    function testSwaps() public virtual;

    // ══════════════════════════════════════════════════ TEST HELPERS ══════════════════════════════════════════════════════

    function initiateBridge(
        function() internal expectEmitOrRevert,
        uint256 chainId,
        address module,
        address token,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) internal virtual {
        uint256 amount = getTestAmount(token);
        mintToken(token, amount);
        approveSpending(token, address(router), amount);

        bytes32 moduleId = moduleIds[module];
        console.log("Bridging %s from chain %s -> %s", tokenNames[token], getChainId(), chainId);
        console.log("   Via module: %s", moduleNames[module]);
        if (originQuery.hasAdapter())
            console.log("   Swapping: %s -> %s before bridging", tokenNames[token], tokenNames[originQuery.tokenOut]);
        if (destQuery.hasAdapter()) {
            address destTokenIn = originQuery.hasAdapter() ? originQuery.tokenOut : token;
            console.log(
                "   Swapping: %s -> %s after bridging",
                tokenNames[destTokenIn],
                tokenNames[destQuery.tokenOut]
            );
        }

        uint256 balanceBefore = IERC20(token).balanceOf(user);
        expectEmitOrRevert();

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

    function initiateSwap(
        address to,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) internal virtual {
        mintToken(token, amount);
        approveSpending(token, address(router), amount);

        address tokenFrom = token;
        address tokenTo = query.tokenOut;
        uint256 expectedAmountOut = query.minAmountOut;

        console.log("Swapping: %s -> %s", tokenNames[tokenFrom], tokenNames[tokenTo]);
        console.log("   Expecting: %s -> %s", amount, expectedAmountOut);

        uint256 balanceFromBefore = IERC20(tokenFrom).balanceOf(user);
        uint256 balanceToBefore = IERC20(tokenTo).balanceOf(to);

        vm.prank(user);
        uint256 amountOut = router.swap(to, token, amount, query);
        assertEq(amountOut, expectedAmountOut, "Failed to get exact quote");

        // check balances after swap
        assertEq(
            IERC20(tokenFrom).balanceOf(user),
            tokenFrom == tokenTo && user == recipient
                ? balanceFromBefore - amount + amountOut
                : balanceFromBefore - amount
        );
        assertEq(
            IERC20(tokenTo).balanceOf(to),
            tokenFrom == tokenTo && user == recipient
                ? balanceToBefore + amountOut - amount
                : balanceToBefore + amountOut
        );
    }

    // ══════════════════════════════════════════════════ GENERIC HELPERS ══════════════════════════════════════════════════════

    function getModuleId(string memory moduleName) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(moduleName));
    }

    function hasParams(SwapQuery memory destQuery) public pure returns (bool) {
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

    function checkBridgeTokenArrays(BridgeToken[] memory actual, BridgeToken[] memory expect) public {
        assertEq(actual.length, expect.length);
        for (uint256 i = 0; i < actual.length; i++) {
            console.log("%s: %s [%s]", i, expect[i].token, expect[i].symbol);
            assertEq(actual[i].symbol, expect[i].symbol);
            assertEq(actual[i].token, expect[i].token);
        }
    }

    function checkAddressArrays(address[] memory actual, address[] memory expect) public {
        assertEq(actual.length, expect.length);
        for (uint256 i = 0; i < actual.length; i++) {
            assertTrue(expect.contains(actual[i]));
        }
    }
}
