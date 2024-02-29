// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {BasicSynapseScript, StringUtils} from "../templates/BasicSynapse.s.sol";
import {console, stdJson} from "forge-std/Script.sol";

import {IERC20Metadata} from "@openzeppelin/contracts-4.8.0/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable no-console
contract SetupCCTPScript is BasicSynapseScript {
    using StringUtils for *;
    using stdJson for string;

    // Alphabetical order should be enforced
    struct CCTPToken {
        uint256 maxFee;
        uint256 minBaseFee;
        uint256 minSwapFee;
        address pool;
        uint256 relayerFee;
        address token;
    }

    string public constant SYMBOL_PREFIX = "CCTP.";

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant ENVIRONMENT = ".testnet";

    SynapseCCTP public synapseCCTP;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        synapseCCTP = SynapseCCTP(getDeploymentAddress(SYNAPSE_CCTP));
        vm.startBroadcast();
        if (synapseCCTP.owner() != msg.sender) {
            console.log("Error: SynapseCCTP owner is not the broadcaster");
            console.log("      Owner: %s", synapseCCTP.owner());
            console.log("Broadcaster: %s", msg.sender);
            vm.stopBroadcast();
            return;
        }
        setupTokensCCTP();
        setupRemoteDeployments();
        setupGasAirdrop();
        // transferOwnership();
        vm.stopBroadcast();
    }

    function setupTokensCCTP() internal {
        string memory config = getDeployConfig(SYNAPSE_CCTP);
        // Get the list of symbols
        string[] memory symbols = vm.parseJsonKeys(config, ".tokens");
        console.log("Setting up %s tokens", symbols.length);
        for (uint256 i = 0; i < symbols.length; i++) {
            string memory symbol = symbols[i];
            CCTPToken memory token = abi.decode(config.parseRaw(string.concat(".tokens.", symbol)), (CCTPToken));
            console.log(
                "   Setting up %s [name: %s] [symbol: %s]",
                symbol,
                IERC20Metadata(token.token).name(),
                IERC20Metadata(token.token).symbol()
            );
            string memory curSymbol = SynapseCCTP(synapseCCTP).tokenToSymbol(token.token);
            if (bytes(curSymbol).length == 0) {
                addNewToken(token, symbol);
            } else {
                setupExistingToken(token, symbol);
            }
            // Setup token pool if needed
            if (token.pool != SynapseCCTP(synapseCCTP).circleTokenPool(token.token)) {
                console.log("            pool: %s", token.pool);
                SynapseCCTP(synapseCCTP).setCircleTokenPool({circleToken: token.token, pool: token.pool});
            } else {
                console.log("            pool: already setup [%s]", token.pool);
            }
        }
    }

    function logTokenInfo(CCTPToken memory token, string memory symbol) public view {
        uint8 decimals = IERC20Metadata(token.token).decimals();
        console.log("           token: %s", token.token);
        console.log("        decimals: %s", decimals);
        console.log("      relayerFee: %s [%s %%]", token.relayerFee, (token.relayerFee / 10**6).fromFloat(2));
        console.log("      minBaseFee: %s [%s %s]", token.minBaseFee, token.minBaseFee.fromFloat(decimals), symbol);
        console.log("      minSwapFee: %s [%s %s]", token.minSwapFee, token.minSwapFee.fromFloat(decimals), symbol);
        console.log("          maxFee: %s [%s %s]", token.maxFee, token.maxFee.fromFloat(decimals), symbol);
    }

    function addNewToken(CCTPToken memory token, string memory symbol) public {
        logTokenInfo(token, symbol);
        // Add new token
        SynapseCCTP(synapseCCTP).addToken({
            symbol: SYMBOL_PREFIX.concat(symbol),
            token: token.token,
            relayerFee: token.relayerFee,
            minBaseFee: token.minBaseFee,
            minSwapFee: token.minSwapFee,
            maxFee: token.maxFee
        });
    }

    function setupExistingToken(CCTPToken memory token, string memory symbol) public {
        (uint256 relayerFee, uint256 minBaseFee, uint256 minSwapFee, uint256 maxFee) = synapseCCTP.feeStructures(
            token.token
        );
        // Do nothing, if all the values are the same
        if (
            relayerFee == token.relayerFee &&
            minBaseFee == token.minBaseFee &&
            minSwapFee == token.minSwapFee &&
            maxFee == token.maxFee
        ) {
            console.log("       Skipping: already setup");
            return;
        }
        // Otherwise, update the values
        logTokenInfo(token, symbol);
        SynapseCCTP(synapseCCTP).setTokenFee({
            token: token.token,
            relayerFee: token.relayerFee,
            minBaseFee: token.minBaseFee,
            minSwapFee: token.minSwapFee,
            maxFee: token.maxFee
        });
    }

    function setupRemoteDeployments() public {
        console.log("Setting up remote deployments");
        string memory config = getGlobalConfig({contractName: SYNAPSE_CCTP, globalProperty: "chains"});
        string[] memory chains = vm.parseJsonKeys(config, ENVIRONMENT.concat(".domains"));
        bool chainFound = false;
        for (uint256 i = 0; i < chains.length; ++i) {
            string memory remoteChain = chains[i];
            console.log("   Checking %s", remoteChain);
            uint32 domain = uint32(config.readUint(ENVIRONMENT.concat(".domains.", remoteChain)));
            // Check if the chain is the same as the current chain
            if (keccak256(bytes(remoteChain)) == keccak256(bytes(activeChain))) {
                require(synapseCCTP.localDomain() == domain, "Incorrect local domain");
                console.log("       Skip: current chain");
                chainFound = true;
                continue;
            }
            address remoteSynapseCCTP = getDeploymentAddress(remoteChain, SYNAPSE_CCTP);
            uint256 chainid = getChainId(remoteChain);
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
        string memory config = getGlobalConfig({contractName: SYNAPSE_CCTP, globalProperty: "chains"});
        uint256 gasAirdrop = config.readUint(ENVIRONMENT.concat(".gasAirdrop.", activeChain));
        uint256 oldGasAirdrop = synapseCCTP.chainGasAmount();
        console.log("   Old gas airdrop: %s", oldGasAirdrop.fromWei());
        console.log("   New gas airdrop: %s", gasAirdrop.fromWei());
        if (gasAirdrop == oldGasAirdrop) {
            console.log("       Skip: already configured");
            return;
        }
        synapseCCTP.setChainGasAmount(gasAirdrop);
        console.log("       Updated");
    }

    function transferOwnership() public {
        console.log("Transferring ownership");
        address newOwner = getDeploymentAddress("DevMultisig");
        console.log("   Old owner: %s", synapseCCTP.owner());
        console.log("   New owner: %s", newOwner);
        synapseCCTP.transferOwnership(newOwner);
        require(synapseCCTP.owner() == newOwner, "Failed to transfer ownership");
        require(newOwner.code.length > 0, "newOwner is not a contract");
    }
}
