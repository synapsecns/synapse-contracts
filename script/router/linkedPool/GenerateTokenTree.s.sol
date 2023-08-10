// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPool} from "../../../contracts/router/LinkedPool.sol";

import {BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";
import {IERC20Metadata} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts-4.5.0/utils/Strings.sol";

contract GenerateTokenTree is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;
    using Strings for uint256;

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

    string public constant GRAPH_HEADER = "graph G {";
    string public constant CLUSTER_HEADER = "subgraph cluster";
    string public constant SUBGRAPH_HEADER = "subgraph {";
    string public constant CLOSING_BRACKET = "}";
    // prettier-ignore
    string public constant QUOTE_SYMBOL = "\"";

    string public config;
    LinkedPool public linkedPool;

    string public graphFN;
    string public graphSVG;

    // (pool index => list of nodes added with the pool)
    mapping(uint256 => uint256[]) public poolToAddedNodes;

    function run(string memory bridgeSymbol) external {
        // Setup the BasicSynapseScript
        setUp();
        string memory configName = StringUtils.concat("LinkedPool.", bridgeSymbol);
        config = getDeployConfig(configName);
        graphFN = genericConfigPath({fileName: configName.concat(".dot")});
        graphSVG = genericConfigPath({fileName: configName.concat(".svg")});
        // Deploy new Linked Pool in a forked environment
        deployLinkedPool();
        addPoolsToTokenTree();
        // Inspect the Linked Pool and generate the graph image file
        printGraph();
        generateSVG();
    }

    // ═════════════════════════════════════════════ LINKED POOL SETUP ═════════════════════════════════════════════════

    /// @notice Deploys a new Linked Pool contract.
    function deployLinkedPool() internal {
        address bridgeToken = config.readAddress(".bridgeToken");
        linkedPool = new LinkedPool(bridgeToken);
    }

    /// @notice Adds pools to the Linked Pool contract.
    function addPoolsToTokenTree() internal {
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            addPoolToTokenTree(i, poolParamsList[i]);
        }
    }

    /// @notice Adds a pool to the Linked Pool contract.
    function addPoolToTokenTree(uint256 poolIndex, PoolParams memory params) internal {
        address poolModule = bytes(params.poolModule).length == 0
            ? address(0)
            : getDeploymentAddress(params.poolModule.concat("Module"));
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
    function printGraph() public {
        // Clear file just in case
        vm.writeFile(graphFN, "");
        printSubgraphHeader(GRAPH_HEADER);
        printNodes();
        printPools();
        closeSubgraph();
        vm.closeFile(graphFN);
    }

    /// @notice Prints the header of the subgraph, and increases the tab count for formatting.
    function printSubgraphHeader(string memory header) internal {
        printGraphLine(header);
        increaseIndent();
    }

    /// @notice Decreases the tab count for formatting, and prints the closing bracket.
    function closeSubgraph() internal {
        decreaseIndent();
        printGraphLine(CLOSING_BRACKET);
    }

    /// @notice Prints descriptions for all token nodes in the Linked Pool's token tree.
    function printNodes() internal {
        string memory symbolOverrides = getGlobalConfig("TokenSymbols", "overrides");
        bytes memory encodedOverrides = symbolOverrides.parseRaw(StringUtils.concat(".", activeChain));
        OverridenToken[] memory overrides = new OverridenToken[](0);
        if (encodedOverrides.length != 0) {
            overrides = abi.decode(encodedOverrides, (OverridenToken[]));
        }
        uint256 numTokens = linkedPool.tokenNodesAmount();
        for (uint256 i = 0; i < numTokens; ++i) {
            address token = linkedPool.getToken(uint8(i));
            string memory symbol = IERC20Metadata(token).symbol();
            // Check if we need to override the symbol
            for (uint256 j = 0; j < overrides.length; ++j) {
                if (overrides[j].tokenAddress == token) {
                    symbol = overrides[j].tokenSymbol;
                    break;
                }
            }
            printNode(i, symbol);
        }
    }

    /// @notice Prints descriptions for all pools in the Linked Pool's token tree.
    function printPools() internal {
        bytes memory encodedPools = config.parseRaw(".pools");
        PoolParams[] memory poolParamsList = abi.decode(encodedPools, (PoolParams[]));
        for (uint256 i = 0; i < poolParamsList.length; ++i) {
            printPool(i, poolParamsList[i]);
        }
    }

    /// @notice Prints a description for a token node in the Linked Pool's token tree.
    function printNode(uint256 index, string memory symbol) internal {
        // Example: "token0 [label = "0: USDC"];"
        string memory line = getNodeName(index).concat(" [", getTokenLabel(index, symbol), "];");
        printGraphLine(line);
    }

    /// @notice Prints a description for a pool in the Linked Pool's token tree.
    /// First, prints the edges between the node that pool was attached to, and the other tokens in the pool.
    /// Then, prints the pool as a subgraph, with the pool's tokens as a subgraph inside.
    function printPool(uint256 poolIndex, PoolParams memory params) internal {
        uint256[] memory addedNodes = poolToAddedNodes[poolIndex];
        require(addedNodes.length != 0, "No nodes added for pool");
        // Example: "pool0 [label = "DefaultPool 0xabcd";shape = rect;style = dashed;];"
        string memory line = getPoolName(poolIndex).concat(" [", getPoolLabel(params), "];");
        printGraphLine(line);
        // Print edge from the parent node to the pool
        printEdge(getNodeName(params.nodeIndex), getPoolName(poolIndex));
        // Print subgraph for the pool: surround with a dotted line
        printSubgraphHeader(CLUSTER_HEADER.concat(poolIndex.toString(), " {"));
        printGraphLine("style = dotted;");
        // Print all the edges from to the pool nodes
        for (uint256 i = 0; i < addedNodes.length; ++i) {
            printEdge(getPoolName(poolIndex), getNodeName(addedNodes[i]));
        }
        {
            // Print inner subgraph for the pool's tokens
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
            printGraphLine(getNodeName(addedNodes[0]).concat(";"));
            return;
        }
        for (uint256 i = 0; i < addedNodes.length - 1; ++i) {
            printEdge(getNodeName(addedNodes[i]), getNodeName(addedNodes[i + 1]));
        }
    }

    /// @notice Returns the label to be used for a token node in the DOT file.
    function getTokenLabel(uint256 index, string memory symbol) internal pure returns (string memory label) {
        // Example: "label = "0: USDC";"
        label = StringUtils.concat("label = ", QUOTE_SYMBOL, index.toString(), ": ");
        label = label.concat(symbol, QUOTE_SYMBOL, ";");
    }

    /// @notice Returns the label to be used for a pool in the DOT file.
    function getPoolLabel(PoolParams memory params) internal pure returns (string memory label) {
        // Example: "label = "DefaultPool 0xabcd;shape = rect;style = dashed;"
        string memory poolName = bytes(params.poolModule).length == 0 ? "DefaultPool" : params.poolModule;
        label = StringUtils.concat("label = ", QUOTE_SYMBOL, poolName, " ");
        string memory shortenedAddress = uint256(uint160(params.pool) >> 144).toHexString();
        label = label.concat(shortenedAddress, QUOTE_SYMBOL, ";shape = rect;style = dashed;");
    }

    /// @notice Returns the name of a token node in the DOT file.
    function getNodeName(uint256 index) internal pure returns (string memory) {
        return StringUtils.concat("token", index.toString());
    }

    /// @notice Returns the name of a pool node in the DOT file.
    function getPoolName(uint256 index) internal pure returns (string memory) {
        return StringUtils.concat("pool", index.toString());
    }

    /// @notice Prints an edge between two nodes in the DOT file.
    function printEdge(string memory from, string memory to) internal {
        string memory line = from.concat(" -- ", to, ";");
        printGraphLine(line);
    }

    /// @notice Prints an arbitrary line to the DOT file.
    function printGraphLine(string memory line) internal {
        vm.writeLine(graphFN, currentIndent().concat(line));
    }
}
