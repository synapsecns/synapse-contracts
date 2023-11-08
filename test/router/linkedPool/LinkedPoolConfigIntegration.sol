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

    // enforce alphabetical order to match the JSON order
    struct OverridenToken {
        address tokenAddress;
        string tokenSymbol;
    }

    struct LoggedQuote {
        uint8 nodeIndexFrom;
        uint8 nodeIndexTo;
        address pool;
        uint256 amountOut;
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
    LoggedQuote[] public zeroQuotes;
    /// @notice List of adjacent nodes that have quote with slippage over 1%
    LoggedQuote[] public slippageQuotes;
    uint256 public constant MAX_SLIPPAGE = 0.01e18;

    address public user;

    /// @dev We don't pin the LinkedPool config tests to a specific block number because we want to be able to run them
    /// against the current state of the chain to test the latest configuration against the current liquidity composition.
    constructor(
        string memory chainName_,
        string memory bridgeSymbol_,
        uint256 swapValue_,
        uint256 maxPercentDelta_
    ) IntegrationUtils(chainName_, linkedPoolAlias = string.concat("LinkedPool.", bridgeSymbol_), 0) {
        user = makeAddr("User");
        swapValue = swapValue_;
        maxPercentDelta = maxPercentDelta_;
    }

    // TODO: remove before merging
    function runIfDeployed() public pure override returns (bool) {
        return true;
    }

    // ═══════════════════════════════════════════════════ SETUP ═══════════════════════════════════════════════════════

    function afterBlockchainForked() public virtual override {
        readPoolConfig();
        deployLinkedPool();
        addPools();
        readTokens();
        // Read overrides after tokens are read to apply them
        readSymbolOverrides();
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

    function readSymbolOverrides() internal {
        string memory overridesJSON = vm.readFile("script/configs/TokenSymbols.overrides.json");
        bytes memory encodedOverrides = overridesJSON.parseRaw(StringUtils.concat(".", chainName));
        // Exit early if there are no overrides for this chain
        if (encodedOverrides.length == 0) return;
        OverridenToken[] memory overrides = abi.decode(encodedOverrides, (OverridenToken[]));
        for (uint256 i = 0; i < overrides.length; i++) {
            tokenSymbols[overrides[i].tokenAddress] = overrides[i].tokenSymbol;
        }
    }

    // ═══════════════════════════════════════════════════ TESTS ═══════════════════════════════════════════════════════

    function testSwapsFromRoot() public {
        for (uint8 nodeIndexFrom = 1; nodeIndexFrom < tokenNodesAmount; nodeIndexFrom++) {
            checkSwap(0, nodeIndexFrom);
        }
        logQuotes();
    }

    function testSwapsToRoot() public {
        for (uint8 nodeIndexTo = 1; nodeIndexTo < tokenNodesAmount; nodeIndexTo++) {
            checkSwap(nodeIndexTo, 0);
        }
        logQuotes();
    }

    function testSwapsBetweenNodes() public {
        for (uint8 nodeIndexFrom = 1; nodeIndexFrom < tokenNodesAmount; nodeIndexFrom++) {
            for (uint8 nodeIndexTo = 1; nodeIndexTo < tokenNodesAmount; nodeIndexTo++) {
                checkSwap(nodeIndexFrom, nodeIndexTo);
            }
        }
        logQuotes();
    }

    function checkSwap(uint8 nodeIndexFrom, uint8 nodeIndexTo) internal {
        if (nodeIndexFrom == nodeIndexTo) {
            return;
        }
        uint256 snapshotId = vm.snapshot();
        uint256 amountIn = getTestAmount(tokens[nodeIndexFrom]);
        uint256 expectedAmountOut = linkedPool.calculateSwap(nodeIndexFrom, nodeIndexTo, amountIn);
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
            saveBadQuote(zeroQuotes, 0, nodeIndexFrom, nodeIndexTo);
        } else if (calculateSlippage(nodeIndexFrom, nodeIndexTo, amountIn, expectedAmountOut) >= MAX_SLIPPAGE) {
            saveBadQuote(slippageQuotes, expectedAmountOut, nodeIndexFrom, nodeIndexTo);
        }
    }

    function calculateSlippage(
        uint8 nodeIndexFrom,
        uint8 nodeIndexTo,
        uint256 amountIn,
        uint256 expectedAmountOut
    ) internal view returns (uint256 slippage) {
        address tokenFrom = tokens[nodeIndexFrom];
        address tokenTo = tokens[nodeIndexTo];
        // Convert to decimals of tokenTo to get the "no-slippage" amount
        uint256 amountOutNoSlippage = (amountIn * 10**tokenDecimals[tokenTo]) / 10**tokenDecimals[tokenFrom];
        if (expectedAmountOut >= amountOutNoSlippage) {
            // Slippage <= 0% (aka positive slippage)
            return 0;
        }
        slippage = ((amountOutNoSlippage - expectedAmountOut) * 1e18) / amountOutNoSlippage;
    }

    function saveBadQuote(
        LoggedQuote[] storage loggedQuotes,
        uint256 amountOut,
        uint8 nodeIndexFrom,
        uint8 nodeIndexTo
    ) internal {
        // Save nodes only if the swap path contains exactly 1 pool to avoid spamming the console
        address pool = commonPool[nodeIndexFrom][nodeIndexTo];
        if (pool == address(0)) return;
        loggedQuotes.push(
            LoggedQuote({nodeIndexFrom: nodeIndexFrom, nodeIndexTo: nodeIndexTo, pool: pool, amountOut: amountOut})
        );
    }

    // ══════════════════════════════════════════════════ LOGGING ══════════════════════════════════════════════════════

    function logQuotes() internal view {
        logQuotes({
            quotes: zeroQuotes,
            description: "amountOut == 0",
            warningMsg: unicode"⛔ Swap is not possible for"
        });
        logQuotes({quotes: slippageQuotes, description: "slippage >= 1%", warningMsg: unicode"💥 High slippage for"});
    }

    function logQuotes(
        LoggedQuote[] storage quotes,
        string memory description,
        string memory warningMsg
    ) internal view {
        console2.log("Quotes with [%s] between adjacent nodes: %s", description, quotes.length);
        for (uint256 i = 0; i < quotes.length; i++) {
            console2.log(unicode"   %s for %s -> %s", warningMsg, quotes[i].nodeIndexFrom, quotes[i].nodeIndexTo);
            address tokenFrom = tokens[quotes[i].nodeIndexFrom];
            address tokenTo = tokens[quotes[i].nodeIndexTo];
            string memory amountOutInfo = quotes[i]
                .amountOut
                .fromFloat({decimals: tokenDecimals[tokenTo], decimalsToLeave: 2})
                .concat(" ", tokenSymbols[tokenTo]);
            console2.log("   %s %s -> %s", swapValue, tokenSymbols[tokenFrom], amountOutInfo);
            if (quotes[i].amountOut != 0) {
                // Multiply by 100 to get a percentage value
                string memory slippage = (100 *
                    calculateSlippage(
                        quotes[i].nodeIndexFrom,
                        quotes[i].nodeIndexTo,
                        getTestAmount(tokenFrom),
                        quotes[i].amountOut
                    )).fromWei({decimalsToLeave: 1});
                console2.log("   pool: %s, slippage: %s%%", quotes[i].pool, slippage);
            } else {
                console2.log("   pool: %s", quotes[i].pool);
            }
        }
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
