// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicSynapseScript, console2} from "../templates/BasicSynapse.s.sol";

contract DeployRouterV1 is BasicSynapseScript {
    uint256 public routerNonce;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        skipToNonce(routerNonce);
        bytes memory constructorArgs = getConstructorArgs();
        deployAndSave({
            contractName: "SynapseRouter",
            constructorArgs: constructorArgs,
            deployCode: deploySolcGenerated
        });
        vm.stopBroadcast();
    }

    function setUp() internal override {
        super.setUp();
        routerNonce = vm.envUint("ROUTER_NONCE");
    }

    function skipToNonce(uint256 nonce) internal {
        uint256 curNonce = vm.getNonce(msg.sender);
        require(curNonce <= nonce, "Nonce misaligned");
        while (curNonce < nonce) {
            console2.log("Skipping nonce: %s", curNonce);
            payable(msg.sender).transfer(0);
            ++curNonce;
        }
        // Sanity check
        require(vm.getNonce(msg.sender) == nonce, "Failed to align the nonce");
        console2.log("Deployer nonce is %s", nonce);
    }

    function getConstructorArgs() internal returns (bytes memory constructorArgs) {
        address bridge = getDeploymentAddress("SynapseBridge");
        address owner = vm.envAddress("OWNER_ADDR");
        constructorArgs = abi.encode(bridge, owner);
    }
}
