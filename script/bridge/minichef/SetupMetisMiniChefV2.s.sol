// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {MiniChefV2, IERC20, IRewarder} from "../../../contracts/bridge/MiniChefV2.sol";

import {BasicSynapseScript, console2} from "../../templates/BasicSynapse.s.sol";

contract SetupMetisMiniChefV2 is BasicSynapseScript {
    string public constant NEW_MINI_CHEF_V2 = "MiniChefV2.METIS";

    MiniChefV2 public miniChefV2;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        miniChefV2 = MiniChefV2(getDeploymentAddress(NEW_MINI_CHEF_V2));
        vm.startBroadcast();
        copySetup();
        transferOwnership();
        vm.stopBroadcast();
    }

    function copySetup() internal {
        MiniChefV2 oldMiniChefV2 = MiniChefV2(getDeploymentAddress("MiniChefV2"));
        uint256 pools = oldMiniChefV2.poolLength();
        for (uint256 i = 0; i < pools; i++) {
            IERC20 lpToken = oldMiniChefV2.lpToken(i);
            (, , uint256 allocPoint) = oldMiniChefV2.poolInfo(i);
            IRewarder rewarder = oldMiniChefV2.rewarder(i);
            console2.log("Adding LP token: %s", address(lpToken));
            console2.log("  AllocPoint: %s", allocPoint);
            console2.log("  Rewarder: %s", address(rewarder));
            miniChefV2.add(allocPoint, lpToken, rewarder);
        }
    }

    function transferOwnership() internal {
        address multisig = getDeploymentAddress("DevMultisig");
        console2.log("Transferring ownership to %s", multisig);
        miniChefV2.transferOwnership({newOwner: multisig, direct: true, renounce: false});
    }
}
