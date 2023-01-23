// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {BaseScript} from "../utils/BaseScript.sol";

import {SynapseDeployFactory} from "../../contracts/factory/SynapseDeployFactory.sol";

contract DeployFactoryScript is BaseScript {
    string public constant FACTORY = "SynapseDeployFactory";
    // @notice Expected nonce for FACTORY_DEPLOYER on chains where Factory is not yet deployed
    uint256 public factoryDeployerNonce;

    constructor() {
        // Load factory deployer private key
        setupPK("FACTORY_DEPLOYER_PRIVATE_KEY");
        // Load chain name for block.chainid
        loadChain();
        // Load expected factory deployer nonce. Expecting zero if no value is specified
        factoryDeployerNonce = vm.envOr("FACTORY_DEPLOYER_NONCE", uint256(0));
    }

    function execute(bool _isBroadcasted) public override {
        startBroadcast(_isBroadcasted);
        address deployment = tryLoadDeployment(FACTORY);
        if (deployment == address(0)) {
            require(vm.getNonce(broadcasterAddress) == factoryDeployerNonce, "Nonces misaligned");
            SynapseDeployFactory _factory = new SynapseDeployFactory();
            saveDeployment(FACTORY, address(_factory));
        } else {
            console.log("Reusing %s deployment: %s", FACTORY, deployment);
        }
        stopBroadcast();
    }
}
