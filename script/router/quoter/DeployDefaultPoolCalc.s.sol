// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DefaultPoolCalc} from "../../../contracts/router/quoter/DefaultPoolCalc.sol";

import {console2, BasicSynapseScript, StringUtils} from "../../templates/BasicSynapse.s.sol";

import {stdJson} from "forge-std/Script.sol";

// solhint-disable no-console
/// @notice This script deploys the DefaultPoolCalc contract in a deterministic way
/// using CREATE2 via `IMMUTABLE_CREATE2_FACTORY`.
contract DeployDefaultPoolCalc is BasicSynapseScript {
    using StringUtils for string;
    using stdJson for string;

    string public constant DEFAULT_POOL_CALC = "DefaultPoolCalc";

    function run() external {
        // Setup the BasicSynapseScript
        setUp();
        vm.startBroadcast();
        // Use `deployCreate2` as callback to deploy the contract with CREATE2
        // This will load deployment salt from the pre-saved list, if there's an entry for the contract
        deployAndSave({contractName: DEFAULT_POOL_CALC, constructorArgs: "", deployCode: deployCreate2});
        vm.stopBroadcast();
    }
}
