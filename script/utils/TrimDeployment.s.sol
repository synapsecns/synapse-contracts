// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";

import {SynapseScript} from "./SynapseScript.sol";

contract TrimDeployment is SynapseScript {
    constructor() public {
        loadChain();
    }

    function trim(string memory contractName) external {
        address deployment = tryLoadDeployment(contractName);
        if (deployment != address(0)) {
            uint256 size;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                size := extcodesize(deployment)
            }
            if (size == 0) {
                console.log("Deployment for %s does not exist on %s", contractName, chain);
                console.log("Deleting %s", _deploymentPath(contractName));
                string[] memory inputs = new string[](2);
                inputs[0] = "rm";
                inputs[1] = _deploymentPath(contractName);
                vm.ffi(inputs);
            } else {
                console.log("Deployment for %s exists on %s", contractName, chain);
            }
        } else {
            console.log("%s has not been deployed on %s", contractName, chain);
        }
    }
}
