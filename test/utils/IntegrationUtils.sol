// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

// solhint-disable no-console
abstract contract IntegrationUtils is Test {
    string private _envRPC;
    uint256 private _forkBlockNumber;

    constructor(string memory envRPC, uint256 forkBlockNumber) {
        _envRPC = envRPC;
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
}
