// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {DeployScript} from "../utils/DeployScript.sol";
import {console, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract SetupCCTPScript is DeployScript {
    using stdJson for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant ENVIRONMENT = ".testnet";

    SynapseCCTP public synapseCCTP;

    constructor() {
        setupPK("CCTP_TESTNET_DEPLOYER_PK");
        // Load chain name that block.chainid refers to
        loadChain();
    }

    /// @notice Logic for executing the script
    function execute(bool isBroadcasted_) public override {
        synapseCCTP = SynapseCCTP(loadDeployment(SYNAPSE_CCTP));
        startBroadcast(isBroadcasted_);
        string memory config = loadGlobalConfig("SynapseCCTP.chains");
        string[] memory chains = config.readStringArray(_concat(ENVIRONMENT, ".chains"));
        bool chainFound = false;
        for (uint256 i = 0; i < chains.length; ++i) {
            string memory remoteChain = chains[i];
            console.log("Checking %s", remoteChain);
            uint32 domain = uint32(config.readUint(_concat(ENVIRONMENT, ".domains.", remoteChain)));
            // Check if the chain is the same as the current chain
            if (keccak256(bytes(remoteChain)) == keccak256(bytes(chain))) {
                require(synapseCCTP.localDomain() == domain, "Incorrect local domain");
                console.log("   Skip: current chain");
                chainFound = true;
                continue;
            }
            address remoteSynapseCCTP = loadRemoteDeployment(remoteChain, SYNAPSE_CCTP);
            uint256 chainid = loadChainId(remoteChain);
            (uint32 domain_, address remoteSynapseCCTP_) = synapseCCTP.remoteDomainConfig(chainid);
            if (remoteSynapseCCTP == remoteSynapseCCTP_ && domain == domain_) {
                console.log("   Skip: already configured");
                continue;
            }
            console.log("   Old: [domain: %s] [synCCTP: %s]", domain_, remoteSynapseCCTP_);
            console.log("   New: [domain: %s] [synCCTP: %s]", domain, remoteSynapseCCTP);
            synapseCCTP.setRemoteDomainConfig(chainid, domain, remoteSynapseCCTP);
        }
        require(chainFound, "Chain not found in .chains");
        stopBroadcast();
    }
}
