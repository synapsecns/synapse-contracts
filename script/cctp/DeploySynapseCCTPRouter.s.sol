// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SynapseCCTPRouter} from "../../contracts/cctp/SynapseCCTPRouter.sol";

import {DeployScript} from "../utils/DeployScript.sol";
import {console, stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
contract DeploySynapseCCTProuterScript is DeployScript {
    using stdJson for string;

    string public constant SYNAPSE_CCTP = "SynapseCCTP";
    string public constant SYNAPSE_CCTP_ROUTER = "SynapseCCTPRouter";

    constructor() {
        setupPK("ROUTER_DEPLOYER_PK");
        // Load chain name that block.chainid refers to
        loadChain();
    }

    /// @notice Logic for executing the script
    function execute(bool isBroadcasted_) public override {
        startBroadcast(isBroadcasted_);
        address synapseCCTP = loadDeployment(SYNAPSE_CCTP);
        SynapseCCTPRouter router = deployCCTPRouter(synapseCCTP);
        stopBroadcast();
        require(router.synapseCCTP() == synapseCCTP, "Failed to set SynapseCCTP");
    }

    function deployCCTPRouter(address synapseCCTP) public returns (SynapseCCTPRouter router) {
        router = new SynapseCCTPRouter(synapseCCTP);
        saveDeployment(SYNAPSE_CCTP_ROUTER, address(router));
    }
}
