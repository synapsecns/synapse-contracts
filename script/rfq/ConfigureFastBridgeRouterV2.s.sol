// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouterV2} from "../../contracts/rfq/FastBridgeRouterV2.sol";

import {console2, BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract ConfigureFastBridgeRouterV2 is BasicSynapseScript {
    FastBridgeRouterV2 public router;

    function setUp() internal override {
        super.setUp();
        address payable routerDeployment = payable(getDeploymentAddress("FastBridgeRouterV2"));
        router = FastBridgeRouterV2(routerDeployment);
    }

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        configureFastBridgeRouterV2();
        vm.stopBroadcast();
    }

    function configureFastBridgeRouterV2() internal {
        address fastBridge = getDeploymentAddress("FastBridge");
        if (router.fastBridge() != fastBridge) {
            router.setFastBridge(fastBridge);
            printLog(string.concat(unicode"✅ Fast bridge set to ", vm.toString(fastBridge)));
        } else {
            printLog(string.concat(unicode"🟡 Skipping: Fast bridge is already set to ", vm.toString(fastBridge)));
        }
        address swapQuoter = getDeploymentAddress("SwapQuoterV2");
        if (router.swapQuoter() != swapQuoter) {
            router.setSwapQuoter(swapQuoter);
            printLog(string.concat(unicode"✅ SwapQuoter set to ", vm.toString(swapQuoter)));
        } else {
            printLog(string.concat(unicode"🟡 Skipping: SwapQuoter is already set to ", vm.toString(swapQuoter)));
        }
    }
}
