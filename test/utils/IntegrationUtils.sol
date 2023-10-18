// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {StringUtils} from "./StringUtils.sol";
import {Test, console} from "forge-std/Test.sol";

// solhint-disable no-console
abstract contract IntegrationUtils is Test {
    using StringUtils for string;

    string private _chainName;
    string private _contractName;

    string private _envRPC;
    uint256 private _forkBlockNumber;

    constructor(
        string memory chainName,
        string memory contractName,
        uint256 forkBlockNumber
    ) {
        // Chain name should be lowercase.
        _chainName = chainName.toLowerCase();
        _contractName = contractName;
        // Environment variable name is CHAIN_NAME_API (uppercase).
        _envRPC = chainName.toUpperCase().concat("_API");
        _forkBlockNumber = forkBlockNumber;
    }

    /// @notice This will be used to run the test contract as a script first in order
    /// to check if the corresponding contract on the chain has already been deployed.
    /// If the contract has been deployed, the integration test will be skipped.
    function run() external view {
        console.log("%s %s", _chainName, _contractName);
    }

    function setUp() public virtual {
        forkBlockchain();
        afterBlockchainForked();
    }

    function forkBlockchain() public virtual {
        string memory rpcURL = vm.envString(_envRPC);
        if (_forkBlockNumber > 0) {
            vm.createSelectFork(rpcURL, _forkBlockNumber);
        } else {
            vm.createSelectFork(rpcURL);
        }
    }

    function afterBlockchainForked() public virtual {}
}
