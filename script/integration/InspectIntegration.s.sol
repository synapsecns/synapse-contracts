// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IntegrationTest} from "../../test/utils/IntegrationTest.sol";

import {console, Script} from "forge-std/Script.sol";

contract InspectIntegration is Script {
    function run(string memory testContractName) external {
        IntegrationTest testContract = IntegrationTest(deployCode(testContractName));
        // Log chain and contract name.
        console.log("%s %s", testContract.chainName(), testContract.contractName());
    }
}
