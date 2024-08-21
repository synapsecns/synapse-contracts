// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter} from "../../contracts/rfq/FastBridgeRouter.sol";

import {BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract BrickFastBridgeRouter is BasicSynapseScript {
    FastBridgeRouter public router;

    function setUp() internal override {
        super.setUp();
        address payable routerDeployment = payable(getDeploymentAddress("FastBridgeRouter"));
        router = FastBridgeRouter(routerDeployment);
    }

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        brickFastBridgeRouter();
        vm.stopBroadcast();
    }

    function brickFastBridgeRouter() internal {
        if (router.fastBridge() != address(0)) {
            router.setFastBridge(address(0));
            printLog(string.concat(unicode"✅ Fast bridge set to zero"));
        } else {
            printLog(string.concat(unicode"🟡 Skipping: Fast bridge is already set to zero"));
        }
    }
}
