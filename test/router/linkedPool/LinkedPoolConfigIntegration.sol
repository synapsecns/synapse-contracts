// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {ModuleNaming} from "../../../script/router/linkedPool/ModuleNaming.sol";
import {StringUtils} from "../../../script/templates/StringUtils.sol";

import {IntegrationUtils} from "../../utils/IntegrationUtils.sol";

import {console2, stdJson} from "forge-std/Test.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";

abstract contract LinkedPoolConfigIntegrationTest is IntegrationUtils {
    using ModuleNaming for string;
    using SafeERC20 for IERC20;
    using stdJson for string;
    using StringUtils for *;

    // enforce alphabetical order to match the JSON order
    struct PoolParams {
        uint256 nodeIndex;
        address pool;
        string poolModule;
    }

    struct NoQuoteFound {
        uint256 nodeIndexFrom;
        uint256 nodeIndexTo;
        address pool;
    }

    LinkedPool public linkedPool;
    uint256 public tokenNodesAmount;
    string public linkedPoolAlias;
    string public linkedPoolConfig;

    address[] public tokens;
    mapping(address => string) public tokenSymbols;
    mapping(address => uint256) public tokenDecimals;
    // nodeIndexFrom => nodeIndexTo => common pools address (zero if none)
    mapping(uint256 => mapping(uint256 => address)) public commonPool;

    /// @notice Swap value to be used as amountIn for all swaps, before token decimals are applied
    /// @dev Use something like 10_000 for USD tokens, 10 for ETH tokens
    uint256 public swapValue;
    /// @notice Maximum percent difference between expected and actual swap amount
    /// @dev An 18 decimal fixed point number, where 1e18 == 100%
    uint256 public maxPercentDelta;

    /// @notice List of adjacent nodes that have no quote
    NoQuoteFound[] public noQuotesFound;

    address public user;

    constructor(
        string memory chainName_,
        uint256 forkBlockNumber,
        string memory bridgeSymbol_,
        uint256 swapValue_,
        uint256 maxPercentDelta_
    ) IntegrationUtils(chainName_, linkedPoolAlias = string.concat("LinkedPool.", bridgeSymbol_), forkBlockNumber) {
        user = makeAddr("User");
        swapValue = swapValue_;
        maxPercentDelta = maxPercentDelta_;
    }

    // ═══════════════════════════════════════════════════ SETUP ═══════════════════════════════════════════════════════

    function afterBlockchainForked() public virtual override {
        readPoolConfig();
        deployLinkedPool();
        addPools();
        readTokens();
    }

    function readPoolConfig() internal virtual {
        string memory configFN = string.concat("script/configs/", chainName, "/", linkedPoolAlias, ".dc.json");
        linkedPoolConfig = vm.readFile(configFN);
    }

    function deployLinkedPool() internal virtual {
        address bridgeToken = linkedPoolConfig.readAddress(".bridgeToken");
        linkedPool = new LinkedPool({bridgeToken: bridgeToken, owner_: address(this)});
    }

    function addPools() internal virtual {
        bytes memory encodedPools = linkedPoolConfig.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; i++) {
            addPool(poolParamsList[i]);
        }
    }

    function addPool(PoolParams memory poolParams) internal virtual {
        address poolModule = bytes(poolParams.poolModule).length == 0
            ? address(0)
            : getDeploymentAddress(poolParams.poolModule.getModuleDeploymentName());
        uint256 amountBefore = linkedPool.tokenNodesAmount();
        linkedPool.addPool(poolParams.nodeIndex, poolParams.pool, poolModule);
        uint256 amountAfter = linkedPool.tokenNodesAmount();
        // New node indexes are [amountBefore, amountAfter)
        for (uint256 i = amountBefore; i < amountAfter; i++) {
            markSamePool(poolParams.nodeIndex, i, poolParams.pool);
            for (uint256 j = amountBefore; j < i; j++) {
                markSamePool(i, j, poolParams.pool);
            }
        }
    }

    function markSamePool(
        uint256 nodeIndexFrom,
        uint256 nodeIndexTo,
        address pool
    ) internal virtual {
        if (nodeIndexFrom == nodeIndexTo) {
            return;
        }
        commonPool[nodeIndexFrom][nodeIndexTo] = pool;
        commonPool[nodeIndexTo][nodeIndexFrom] = pool;
    }

    function readTokens() internal virtual {
        tokenNodesAmount = linkedPool.tokenNodesAmount();
        for (uint8 i = 0; i < tokenNodesAmount; i++) {
            address token = linkedPool.getToken(i);
            tokens.push(token);
            tokenSymbols[token] = IERC20Metadata(token).symbol();
            tokenDecimals[token] = IERC20Metadata(token).decimals();
        }
    }

    // ═══════════════════════════════════════════════════ TESTS ═══════════════════════════════════════════════════════

    function testSwapsFromRoot() public {
        for (uint8 nodeIndexFrom = 1; nodeIndexFrom < tokenNodesAmount; nodeIndexFrom++) {
            checkSwap(0, nodeIndexFrom);
        }
        logNoQuotesFound();
    }

    function testSwapsToRoot() public {
        for (uint8 nodeIndexTo = 1; nodeIndexTo < tokenNodesAmount; nodeIndexTo++) {
            checkSwap(nodeIndexTo, 0);
        }
        logNoQuotesFound();
    }

    function testSwapsBetweenNodes() public {
        for (uint8 nodeIndexFrom = 1; nodeIndexFrom < tokenNodesAmount; nodeIndexFrom++) {
            for (uint8 nodeIndexTo = 1; nodeIndexTo < tokenNodesAmount; nodeIndexTo++) {
                checkSwap(nodeIndexFrom, nodeIndexTo);
            }
        }
        logNoQuotesFound();
    }

    function checkSwap(uint8 nodeIndexFrom, uint8 nodeIndexTo) internal {
        if (nodeIndexFrom == nodeIndexTo) {
            return;
        }
        uint256 snapshotId = vm.snapshot();
        (uint256 amountIn, uint256 expectedAmountOut) = logExpectedSwap(nodeIndexFrom, nodeIndexTo);
        // Record balance before minting in case tokenFrom == tokenTo
        uint256 amountBefore = IERC20(tokens[nodeIndexTo]).balanceOf(user);
        prepareUser(tokens[nodeIndexFrom], amountIn);
        if (expectedAmountOut == 0) {
            vm.expectRevert();
        }
        vm.prank(user);
        linkedPool.swap({
            nodeIndexFrom: nodeIndexFrom,
            nodeIndexTo: nodeIndexTo,
            dx: amountIn,
            minDy: 0,
            deadline: block.timestamp
        });
        if (expectedAmountOut > 0) {
            uint256 amountAfter = IERC20(tokens[nodeIndexTo]).balanceOf(user);
            // Check that the amount out is within the expected range
            assertApproxEqRelDecimal({
                a: amountAfter - amountBefore,
                b: expectedAmountOut,
                maxPercentDelta: maxPercentDelta,
                decimals: tokenDecimals[tokens[nodeIndexTo]]
            });
        }
        // Revert to the snapshot to reset the balances
        // This way every test is independent
        assert(vm.revertTo(snapshotId));
        // Save nodes with no quotes after resetting the state
        if (expectedAmountOut == 0) {
            saveAmountOutZero(nodeIndexFrom, nodeIndexTo);
        }
    }

    function saveAmountOutZero(uint8 nodeIndexFrom, uint8 nodeIndexTo) internal {
        // Save nodes only if the swap path contains exactly 1 pool to avoid spamming the console
        address pool = commonPool[nodeIndexFrom][nodeIndexTo];
        if (pool == address(0)) return;
        noQuotesFound.push(NoQuoteFound({nodeIndexFrom: nodeIndexFrom, nodeIndexTo: nodeIndexTo, pool: pool}));
    }

    // ══════════════════════════════════════════════════ LOGGING ══════════════════════════════════════════════════════

    function logExpectedSwap(uint8 nodeIndexFrom, uint8 nodeIndexTo)
        internal
        view
        returns (uint256 amountIn, uint256 expectedAmountOut)
    {
        address tokenFrom = tokens[nodeIndexFrom];
        address tokenTo = tokens[nodeIndexTo];
        amountIn = getTestAmount(tokenFrom);
        expectedAmountOut = linkedPool.calculateSwap(nodeIndexFrom, nodeIndexTo, amountIn);
        console2.log("Swapping %s -> %s", nodeIndexFrom, nodeIndexTo);
        console2.log("   amountIn: %s %s", amountIn.fromFloat(tokenDecimals[tokenFrom]), tokenSymbols[tokenFrom]);
        console2.log("  amountOut: %s %s", expectedAmountOut.fromFloat(tokenDecimals[tokenTo]), tokenSymbols[tokenTo]);
    }

    function logNoQuotesFound() internal view {
        console2.log("Zero quotes found between adjacent nodes: %s", noQuotesFound.length);
        for (uint256 i = 0; i < noQuotesFound.length; i++) {
            logAmountOutZero(noQuotesFound[i]);
        }
    }

    function logAmountOutZero(NoQuoteFound memory absentQuote) internal view {
        console2.log(
            unicode"❗❗❗ WARNING: no quote for %s -> %s",
            absentQuote.nodeIndexFrom,
            absentQuote.nodeIndexTo
        );
        address tokenFrom = tokens[absentQuote.nodeIndexFrom];
        address tokenTo = tokens[absentQuote.nodeIndexTo];
        console2.log("   %s %s -> %s", swapValue, tokenSymbols[tokenFrom], tokenSymbols[tokenTo]);
        console2.log("   pool: %s", absentQuote.pool);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function getDeploymentAddress(string memory contractAlias) internal view returns (address) {
        string memory deploymentFN = string.concat("deployments/", chainName, "/", contractAlias, ".json");
        string memory deploymentJSON = vm.readFile(deploymentFN);
        return deploymentJSON.readAddress(".address");
    }

    function getTestAmount(address token) internal view virtual returns (uint256) {
        return swapValue * 10**IERC20Metadata(token).decimals();
    }

    // Could be overridden if `deal` does not work with the token
    function setBalance(address token, uint256 amount) internal virtual {
        deal(token, user, amount);
    }

    function prepareUser(address token, uint256 amount) internal {
        setBalance(token, amount);
        vm.startPrank(user);
        IERC20(token).safeApprove(address(linkedPool), amount);
        vm.stopPrank();
    }
}
