// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger, SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {DeployScript} from "../utils/DeployScript.sol";
import {console, stdJson} from "forge-std/Script.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable no-console
contract DeploySynapseCCTPScript is DeployScript {
    using stdJson for string;

    // Alphabetical order should be enforced
    struct CCTPToken {
        uint256 maxFee;
        uint256 minBaseFee;
        uint256 minSwapFee;
        uint256 relayerFee;
        address token;
    }

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant SYMBOL_PREFIX = "CCTP.";

    address public synapseCCTP;

    constructor() {
        setupPK("CCTP_TESTNET_DEPLOYER_PK");
        // Load chain name that block.chainid refers to
        loadChain();
    }

    /// @notice Logic for executing the script
    function execute(bool isBroadcasted_) public override {
        startBroadcast(isBroadcasted_);
        synapseCCTP = tryLoadDeployment(SYNAPSE_CCTP);
        if (synapseCCTP != address(0)) {
            console.log("SynapseCCTP already deployed at %s", synapseCCTP);
            return;
        }
        string memory config = loadDeployConfig(SYNAPSE_CCTP);
        deploySynapseCCTP(config);
        setupTokensCCTP(config);
        stopBroadcast();
    }

    function deploySynapseCCTP(string memory config) internal {
        // Deploy SynapseCCTP
        address tokenMessenger = config.readAddress(".tokenMessenger");
        require(tokenMessenger != address(0), "TokenMessenger not set");
        synapseCCTP = address(new SynapseCCTP(ITokenMessenger(tokenMessenger)));
        saveDeployment(SYNAPSE_CCTP, synapseCCTP);
    }

    function setupTokensCCTP(string memory config) internal {
        // Get the list of symbols
        string[] memory symbols = config.readStringArray(".tokens.symbols");
        console.log("Setting up %s tokens", symbols.length);
        for (uint256 i = 0; i < symbols.length; i++) {
            string memory symbol = symbols[i];
            CCTPToken memory token = abi.decode(config.parseRaw(_concat(".tokens.", symbol)), (CCTPToken));
            console.log(
                "   Setting up %s [name: %s] [symbol: %s]",
                symbol,
                IERC20Metadata(token.token).name(),
                IERC20Metadata(token.token).symbol()
            );
            console.log("           token: %s", token.token);
            console.log("      relayerFee: %s", token.relayerFee);
            console.log("      minBaseFee: %s", token.minBaseFee);
            console.log("      minSwapFee: %s", token.minSwapFee);
            console.log("          maxFee: %s", token.maxFee);
            // Setup token
            SynapseCCTP(synapseCCTP).addToken({
                symbol: _concat(SYMBOL_PREFIX, symbol),
                token: token.token,
                relayerFee: token.relayerFee,
                minBaseFee: token.minBaseFee,
                minSwapFee: token.minSwapFee,
                maxFee: token.maxFee
            });
        }
    }
}
