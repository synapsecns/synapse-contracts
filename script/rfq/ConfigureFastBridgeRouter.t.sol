// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {FastBridgeRouter} from "../../contracts/rfq/FastBridgeRouter.sol";

import {console2, BasicSynapseScript} from "../templates/BasicSynapse.s.sol";

contract ConfigureFastBridgeRouter is BasicSynapseScript {
    string public constant FAST_BRIDGE_ROUTER = "FastBridgeRouter";

    FastBridgeRouter public fastBridgeRouter;

    function setUp() internal override {
        super.setUp();
        address payable routerDeployment = payable(getDeploymentAddress(FAST_BRIDGE_ROUTER));
        fastBridgeRouter = FastBridgeRouter(routerDeployment);
    }

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        configureFastBridgeRouter();
        vm.stopBroadcast();
    }

    function configureFastBridgeRouter() internal {
        address fastBridge = getDeploymentAddress("FastBridge");
        if (fastBridgeRouter.fastBridge() != fastBridge) {
            printLog("Setting FastBridge address to %s", fastBridge);
            fastBridgeRouter.setFastBridge(fastBridge);
        }
        address swapQuoter = getDeploymentAddress("SwapQuoterV2");
        if (fastBridgeRouter.swapQuoter() != swapQuoter) {
            printLog("Setting SwapQuoter address to %s", swapQuoter);
            fastBridgeRouter.setSwapQuoter(swapQuoter);
        }
    }
}
