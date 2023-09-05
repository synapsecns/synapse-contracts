// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {GMXV1StableAvalancheModule} from "../../../../../contracts/router/modules/pool/gmx/GMXV1StableAvalancheModule.sol";

import {BasicSynapseScript} from "../../../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployGMXV1StableAvalancheModule is BasicSynapseScript {
    using stdJson for string;

    string public constant GMX_V1_STABLE_AVAX_MODULE = "GMXV1StableAvalancheModule";

    address public router;
    address public reader;

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        readConfig();
        // Use `deployGMXV1StableAvalanceModule` as callback to deploy the contract
        address module = deployAndSave({
            contractName: GMX_V1_STABLE_AVAX_MODULE,
            deployContract: deployGMXV1StableAvalancheModule
        });
        vm.stopBroadcast();
        // Verify the module was deployed correctly
        require(address(GMXV1StableAvalancheModule(module).router()) == router, "!router");
        require(address(GMXV1StableAvalancheModule(module).reader()) == reader, "!reader");
    }

    function readConfig() internal {
        string memory config = getDeployConfig(GMX_V1_STABLE_AVAX_MODULE);
        router = config.readAddress(".router");
        reader = config.readAddress(".reader");
    }

    /// @notice Callback function to deploy the GMXV1StableAvalancheModule contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployGMXV1StableAvalancheModule() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new GMXV1StableAvalancheModule(router, reader));
        constructorArgs = abi.encode(router, reader);
    }
}
