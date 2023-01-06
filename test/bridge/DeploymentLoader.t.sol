// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../../script/utils/DeploymentLoader.sol";

// solhint-disable func-name-mixedcase
contract DeploymentLoaderTest is Test {
    DeploymentLoader internal loader;

    function setUp() public {
        loader = new DeploymentLoader();
    }

    function test_loadChains() public {
        string memory bridge = "SynapseBridge";
        (bytes[] memory chains, uint256[] memory chainIds) = loader.loadChains();
        for (uint256 i = 0; i < chains.length; ++i) {
            string memory chain = string(chains[i]);
            console.log("%s: %s", chain, chainIds[i]);
            console.log("Bridge: %s", loader.loadDeploymentAddress(chain, bridge));
            console.log("====================");
        }
    }
}
