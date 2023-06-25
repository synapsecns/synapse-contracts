// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ITokenMessenger, SynapseCCTP} from "../../contracts/cctp/SynapseCCTP.sol";

import {DeployScript} from "../utils/DeployScript.sol";
import {console, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract DeploySynapseCCTPScript is DeployScript {
    using stdJson for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";

    address public synapseCCTP;
    address public owner;

    constructor() {
        setupPK("ROUTER_DEPLOYER_PK");
        owner = loadAddress("OWNER_PK");
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
        stopBroadcast();
        require(SynapseCCTP(synapseCCTP).owner() == owner, "Failed to set owner");
    }

    function deploySynapseCCTP(string memory config) internal {
        // Deploy SynapseCCTP if not deployed already
        address tokenMessenger = config.readAddress(".tokenMessenger");
        require(tokenMessenger != address(0), "TokenMessenger not set");
        require(owner != address(0), "Owner not set");
        synapseCCTP = address(new SynapseCCTP(ITokenMessenger(tokenMessenger), owner));
        saveDeployment(SYNAPSE_CCTP, synapseCCTP);
    }
}
