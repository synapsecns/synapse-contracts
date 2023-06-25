// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {DeployScript} from "../utils/DeployScript.sol";
import {console, stdJson} from "forge-std/Script.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable no-console
contract SetupCCTPScript is DeployScript {
    using stdJson for string;

    // Alphabetical order should be enforced
    struct CCTPToken {
        uint256 maxFee;
        uint256 minBaseFee;
        uint256 minSwapFee;
        uint256 relayerFee;
        address token;
    }

    string public constant SYMBOL_PREFIX = "CCTP.";

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant ENVIRONMENT = ".mainnet";

    SynapseCCTP public synapseCCTP;

    constructor() {
        setupPK("OWNER_PK");
        // Load chain name that block.chainid refers to
        loadChain();
    }

    /// @notice Logic for executing the script
    function execute(bool isBroadcasted_) public override {
        synapseCCTP = SynapseCCTP(loadDeployment(SYNAPSE_CCTP));
        startBroadcast(isBroadcasted_);
        setupTokensCCTP();
        setupRemoteDeployments();
        setupGasAirdrop();
        stopBroadcast();
    }

    function setupTokensCCTP() internal {
        string memory config = loadDeployConfig(SYNAPSE_CCTP);
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
            string memory curSymbol = SynapseCCTP(synapseCCTP).tokenToSymbol(token.token);
            if (bytes(curSymbol).length > 0) {
                console.log("       Skipping: already setup");
                continue;
            }
            uint8 decimals = IERC20Metadata(token.token).decimals();
            console.log("           token: %s", token.token);
            console.log("        decimals: %s", decimals);
            console.log("      relayerFee: %s [%s %%]", token.relayerFee, _castToFloat(token.relayerFee / 10**6, 2));
            console.log(
                "      minBaseFee: %s [%s %s]",
                token.minBaseFee,
                _castToFloat(token.minBaseFee, decimals),
                symbol
            );
            console.log(
                "      minSwapFee: %s [%s %s]",
                token.minSwapFee,
                _castToFloat(token.minSwapFee, decimals),
                symbol
            );
            console.log("          maxFee: %s [%s %s]", token.maxFee, _castToFloat(token.maxFee, decimals), symbol);
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

    function setupRemoteDeployments() public {
        console.log("Setting up remote deployments");
        string memory config = loadGlobalConfig("SynapseCCTP.chains");
        string[] memory chains = config.readStringArray(_concat(ENVIRONMENT, ".chains"));
        bool chainFound = false;
        for (uint256 i = 0; i < chains.length; ++i) {
            string memory remoteChain = chains[i];
            console.log("   Checking %s", remoteChain);
            uint32 domain = uint32(config.readUint(_concat(ENVIRONMENT, ".domains.", remoteChain)));
            // Check if the chain is the same as the current chain
            if (keccak256(bytes(remoteChain)) == keccak256(bytes(chain))) {
                require(synapseCCTP.localDomain() == domain, "Incorrect local domain");
                console.log("       Skip: current chain");
                chainFound = true;
                continue;
            }
            address remoteSynapseCCTP = loadRemoteDeployment(remoteChain, SYNAPSE_CCTP);
            uint256 chainid = loadChainId(remoteChain);
            (uint32 domain_, address remoteSynapseCCTP_) = synapseCCTP.remoteDomainConfig(chainid);
            if (remoteSynapseCCTP == remoteSynapseCCTP_ && domain == domain_) {
                console.log("       Skip: already configured");
                continue;
            }
            console.log("       Old: [domain: %s] [synCCTP: %s]", domain_, remoteSynapseCCTP_);
            console.log("       New: [domain: %s] [synCCTP: %s]", domain, remoteSynapseCCTP);
            synapseCCTP.setRemoteDomainConfig(chainid, domain, remoteSynapseCCTP);
        }
        require(chainFound, "Chain not found in .chains");
    }

    function setupGasAirdrop() public {
        console.log("Setting up gas airdrop");
        string memory config = loadGlobalConfig("SynapseCCTP.chains");
        uint256 gasAirdrop = config.readUint(_concat(ENVIRONMENT, ".gasAirdrop.", chain));
        uint256 oldGasAirdrop = synapseCCTP.chainGasAmount();
        console.log("   Old gas airdrop: %s", _fromWei(oldGasAirdrop));
        console.log("   New gas airdrop: %s", _fromWei(gasAirdrop));
        if (gasAirdrop == oldGasAirdrop) {
            console.log("       Skip: already configured");
            return;
        }
        synapseCCTP.setChainGasAmount(gasAirdrop);
        console.log("       Updated");
    }
}
