// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import {IntegrationTest} from "./IntegrationTest.sol";
import {StringUtils} from "./StringUtils.sol";
import {Test, console} from "forge-std/Test.sol";

// solhint-disable no-console
abstract contract IntegrationUtils is Test, IntegrationTest {
    using StringUtils for string;

    /// @inheritdoc IntegrationTest
    string public chainName;
    /// @inheritdoc IntegrationTest
    string public contractName;

    string private _envRPC;
    uint256 private _forkBlockNumber;

    constructor(
        string memory chainName_,
        string memory contractName_,
        uint256 forkBlockNumber
    ) {
        // Chain name should be lowercase.
        chainName = chainName_.toLowerCase();
        contractName = contractName_;
        // Environment variable name is CHAIN_NAME_API (uppercase).
        _envRPC = chainName_.toUpperCase().concat("_API");
        _forkBlockNumber = forkBlockNumber;
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

    /// @inheritdoc IntegrationTest
    function runIfDeployed() external view virtual returns (bool) {
        return false;
    }
}
