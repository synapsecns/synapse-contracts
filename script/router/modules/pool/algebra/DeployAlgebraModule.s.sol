// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AlgebraModule} from "../../../../../contracts/router/modules/pool/algebra/AlgebraModule.sol";

import {BasicSynapseScript, StringUtils} from "../../../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

contract DeployAlgebraModule is BasicSynapseScript {
    using stdJson for string;
    using StringUtils for string;

    string public constant ALGEBRA = "Algebra";
    string public constant ALGEBRA_MODULE = "AlgebraModule";

    address public algebraRouter;
    address public staticQuoter;

    function run(string memory algebraForkName) external {
        string memory key = string.concat(".", algebraForkName);
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        readConfig(key);
        // Use `deployAlgebraModule` as callback to deploy the contract
        address module = deployAndSaveAs({
            contractName: ALGEBRA_MODULE,
            contractAlias: ALGEBRA.concat(key, "Module"),
            deployContract: deployAlgebraModule
        });
        vm.stopBroadcast();
        // Verify the module was deployed correctly
        require(address(AlgebraModule(module).algebraRouter()) == algebraRouter, "!algebraRouter");
        require(address(AlgebraModule(module).algebraStaticQuoter()) == staticQuoter, "!staticQuoter");
    }

    function readConfig(string memory key) internal {
        string memory config = getDeployConfig(ALGEBRA_MODULE);
        algebraRouter = config.readAddress(key.concat(".algebraRouter"));
        staticQuoter = config.readAddress(key.concat(".algebraStaticQuoter"));
    }

    /// @notice Callback function to deploy the AlgebraModule contract.
    /// Must follow this signature for the deploy script to work:
    /// `deployContract() internal returns (address deployedAt, bytes memory constructorArgs)`
    function deployAlgebraModule() internal returns (address deployedAt, bytes memory constructorArgs) {
        deployedAt = address(new AlgebraModule(algebraRouter, staticQuoter));
        constructorArgs = abi.encode(algebraRouter, staticQuoter);
    }
}
