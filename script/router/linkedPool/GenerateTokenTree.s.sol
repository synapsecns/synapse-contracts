// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {SynapseScript} from "../../utils/SynapseScript.sol";

import {console, stdJson} from "forge-std/Script.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts-4.5.0/utils/Strings.sol";

// solhint-disable no-console
contract GenerateTokenTreeScript is SynapseScript {
    using stdJson for string;
    using Strings for uint256;

    // enforce alphabetical order to match the JSON order
    struct PoolParams {
        uint256 nodeIndex;
        address pool;
        string poolModule;
    }

    string public constant DIGRAPH_HEADER = "digraph G {";
    string public constant CLUSTER_HEADER = "subgraph cluster";
    string public constant SUBGRAPH_HEADER = "subgraph {";
    string public constant CLOSING_BRACKET = "}";
    // prettier-ignore
    string public constant QUOTE_SYMBOL = "\"";
    string public constant TAB = "    ";

    LinkedPool public linkedPool;

    uint256 public tabCount;

    string public graphFN;
    string public graphSVG;

    // (pool index => list of nodes added with the pool)
    mapping(uint256 => uint256[]) public poolToAddedNodes;

    function run(string memory bridgeSymbol) external {
        // Load chain name that block.chainid refers to
        loadChain();
        string memory configName = _concat("LinkedPool.", bridgeSymbol);
        string memory config = loadDeployConfig(configName);
        graphFN = _concat(DEPLOY_CONFIGS, chain, "/", configName, ".dot");
        graphSVG = _concat(DEPLOY_CONFIGS, chain, "/", configName, ".svg");
        // Deploy new Linked Pool in a forked environment
        deployLinkedPool(config);
        addPoolsToTokenTree(config);
        // Inspect the Linked Pool and generate the graph image file
        printGraph(config);
        generateSVG();
    }

    // ═════════════════════════════════════════════ LINKED POOL SETUP ═════════════════════════════════════════════════

    /// @notice Deploys a new Linked Pool contract.
    function deployLinkedPool(string memory config) internal {
        address bridgeToken = config.readAddress(".bridgeToken");
        linkedPool = new LinkedPool(bridgeToken);
    }

    /// @notice Adds pools to the Linked Pool contract.
    function addPoolsToTokenTree(string memory config) internal {
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            addPoolToTokenTree(i, poolParamsList[i]);
        }
    }

    /// @notice Adds a pool to the Linked Pool contract.
    function addPoolToTokenTree(uint256 poolIndex, PoolParams memory params) internal {
        address poolModule = bytes(params.poolModule).length == 0 ? address(0) : loadDeployment(params.poolModule);
        uint256 numNodes = linkedPool.tokenNodesAmount();
        linkedPool.addPool(params.nodeIndex, params.pool, poolModule);
        // Save newly added nodes for later
        uint256 newNumNodes = linkedPool.tokenNodesAmount();
        for (uint256 i = numNodes; i < newNumNodes; ++i) {
            poolToAddedNodes[poolIndex].push(i);
        }
    }

    // ═════════════════════════════════════════════ IMAGE GENERATION ══════════════════════════════════════════════════

    /// @notice Generates SVG image from the DOT file.
    function generateSVG() internal {
        string[] memory inputs = new string[](5);
        inputs[0] = "dot";
        inputs[1] = "-Tsvg";
        inputs[2] = graphFN;
        inputs[3] = "-o";
        inputs[4] = graphSVG;
        vm.ffi(inputs);
    }

    /// @notice Prints the DOT file describing the token tree.
    function printGraph(string memory config) public {
        // Clear file just in case
        vm.writeFile(graphFN, "");
        printSubgraphHeader(DIGRAPH_HEADER);
        printNodes();
        printPools(config);
        closeSubgraph();
        vm.closeFile(graphFN);
    }

    /// @notice Prints the header of the subgraph, and increases the tab count for formatting.
    function printSubgraphHeader(string memory header) internal {
        printGraphLine(header);
        ++tabCount;
    }

    /// @notice Decreases the tab count for formatting, and prints the closing bracket.
    function closeSubgraph() internal {
        --tabCount;
        printGraphLine(CLOSING_BRACKET);
    }

    /// @notice Prints descriptions for all token nodes in the Linked Pool's token tree.
    function printNodes() internal {
        uint256 numTokens = linkedPool.tokenNodesAmount();
        for (uint256 i = 0; i < numTokens; ++i) {
            address token = linkedPool.getToken(uint8(i));
            string memory symbol = IERC20Metadata(token).symbol();
            printNode(i, symbol);
        }
    }

    /// @notice Prints descriptions for all pools in the Linked Pool's token tree.
    function printPools(string memory config) internal {
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            printPool(i, poolParamsList[i]);
        }
    }

    /// @notice Prints a description for a token node in the Linked Pool's token tree.
    function printNode(uint256 index, string memory symbol) internal {
        // Example: "token0 [label = "0: USDC"];"
        string memory line = _concat(getNodeName(index), " [", getTokenLabel(index, symbol), "];");
        printGraphLine(line);
    }

    /// @notice Prints a description for a pool in the Linked Pool's token tree.
    /// First, prints the edges between the node that pool was attached to, and the other tokens in the pool.
    /// Then, prints the pool as a subgraph, with the pool's tokens as a subgraph inside.
    function printPool(uint256 poolIndex, PoolParams memory params) internal {
        uint256[] memory addedNodes = poolToAddedNodes[poolIndex];
        require(addedNodes.length != 0, "No nodes added for pool");
        // Print all the edges from the parent node
        for (uint256 i = 0; i < addedNodes.length; ++i) {
            printEdge(params.nodeIndex, addedNodes[i]);
        }
        printSubgraphHeader(_concat(CLUSTER_HEADER, poolIndex.toString(), " {"));
        printGraphLine(getPoolLabel(params));
        {
            printSubgraphHeader(SUBGRAPH_HEADER);
            // We want the pool's tokens to be on the same height
            // So we draw invisible edges between them specifying equal rank
            printGraphLine("rank = same;");
            printGraphLine("edge [style = invis;];");
            // Print all the edges between the pool's tokens
            printInnerEdges(addedNodes);
            closeSubgraph();
        }
        closeSubgraph();
    }

    /// @notice Prints the edges between the pool's tokens.
    function printInnerEdges(uint256[] memory addedNodes) internal {
        if (addedNodes.length == 1) {
            printGraphLine(_concat(getNodeName(addedNodes[0]), ";"));
            return;
        }
        for (uint256 i = 0; i < addedNodes.length - 1; ++i) {
            printEdge(addedNodes[i], addedNodes[i + 1]);
        }
    }

    /// @notice Returns the label to be used for a token node in the DOT file.
    function getTokenLabel(uint256 index, string memory symbol) internal pure returns (string memory label) {
        // Example: "label = "0: USDC";"
        label = _concat("label = ", QUOTE_SYMBOL, index.toString(), ": ");
        label = _concat(label, symbol, QUOTE_SYMBOL, ";");
    }

    /// @notice Returns the label to be used for a pool in the DOT file.
    function getPoolLabel(PoolParams memory params) internal pure returns (string memory label) {
        // Example: "label = "DefaultPool 0xabcd;"
        string memory poolName = bytes(params.poolModule).length == 0 ? "DefaultPool" : params.poolModule;
        label = _concat("label = ", QUOTE_SYMBOL, poolName, " ");
        string memory shortenedAddress = uint256(uint160(params.pool) >> 144).toHexString();
        label = _concat(label, shortenedAddress, QUOTE_SYMBOL, ";");
    }

    /// @notice Returns the name of a token node in the DOT file.
    function getNodeName(uint256 index) internal pure returns (string memory) {
        return _concat("token", index.toString());
    }

    /// @notice Prints an edge between two nodes in the DOT file.
    function printEdge(uint256 indexFrom, uint256 indexTo) internal {
        string memory line = _concat(getNodeName(indexFrom), " -> ", getNodeName(indexTo), ";");
        printGraphLine(line);
    }

    /// @notice Prints an arbitrary line to the DOT file.
    function printGraphLine(string memory line) internal {
        vm.writeLine(graphFN, _concat(createTabs(tabCount), line));
    }

    /// @notice Creates a string with the specified number of tabs to be used for indentation.
    function createTabs(uint256 tabs) internal pure returns (string memory result) {
        result = "";
        for (uint256 i = 0; i < tabs; ++i) {
            result = _concat(result, TAB);
        }
    }
}
