// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {PrivateFactory} from "../../contracts/concentrated/PrivateFactory.sol";

contract DeployPrivateFactory is Script {
    PrivateFactory public factory;

    function run(address owner, address bridge) external {
        vm.startBroadcast();

        factory = new PrivateFactory(bridge);
        factory.setOwner(owner);

        vm.stopBroadcast();
    }
}
